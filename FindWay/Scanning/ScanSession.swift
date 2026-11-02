import ARKit
import FindWayCore

/// Runs the camera while the person walks through their home, records the paths
/// they walk, lets them name spots, and coaches them out loud.
final class ScanSession: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var statusText = "Starting the camera."
    @Published private(set) var placeCount = 0
    @Published private(set) var metersWalked: Int = 0
    @Published private(set) var isSaving = false

    let session = ARSession()

    private(set) var home: HomeData
    private let store: HomeStore
    private let previousMap: ARWorldMap?
    private let speaker = Speaker.shared
    private let haptics = Haptics()

    private var throttle = AnnouncementThrottle(minimumGap: 2.5, repeatAfter: 10)
    private var lastProcessed: TimeInterval = 0
    private var currentPosition: Point3?
    private var tracking: TrackingCondition = .starting
    private var mapping: MappingCondition = .none
    private var lastMappedAnnouncement: TimeInterval = -.greatestFiniteMagnitude
    /// When continuing an earlier scan, nothing is recorded until ARKit recognizes the home.
    private var hasRecognizedHome: Bool

    var isContinuing: Bool { previousMap != nil }

    /// - Parameters:
    ///   - existing: the saved home when continuing a scan, `nil` for a brand-new scan.
    ///   - worldMap: the saved camera map when continuing a scan.
    init(store: HomeStore, existing: HomeData?, worldMap: ARWorldMap?) {
        self.store = store
        self.previousMap = worldMap
        self.home = (worldMap != nil ? existing : nil) ?? HomeData()
        self.hasRecognizedHome = worldMap == nil
        super.init()
        placeCount = home.places.count
        session.delegate = self
    }

    // MARK: - Start and stop

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            statusText = "This iPhone can't run FindWay's camera mapping."
            speaker.speak(statusText)
            return
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.initialWorldMap = previousMap
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        if isContinuing {
            statusText = "Look around slowly so I can recognize your home from the last scan."
        } else {
            statusText = "Scanning started. Hold the phone up at chest height with the back camera facing forward. Walk slowly and turn to look around."
        }
        speaker.speak(statusText)
    }

    func stop() {
        session.pause()
    }

    // MARK: - Camera updates

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Ten updates a second is plenty and saves battery.
        let now = frame.timestamp
        guard now - lastProcessed >= 0.1 else { return }
        lastProcessed = now

        tracking = frame.camera.trackingState.condition
        mapping = frame.worldMappingStatus.condition

        if tracking == .good {
            if !hasRecognizedHome {
                hasRecognizedHome = true
                haptics.success()
                speak("Found your home. Keep scanning to add more.", key: "recognized", urgent: true, now: now)
            }
            let position = frame.camera.transform.position
            currentPosition = position
            if home.trail.walk(to: position) {
                metersWalked = Int(home.trail.totalLength.rounded())
            }
        } else {
            currentPosition = nil
            home.trail.breakTrail()
        }

        coach(frame: frame, now: now)
    }

    private func coach(frame: ARFrame, now: TimeInterval) {
        if !hasRecognizedHome {
            setStatus("Still looking for your home. Stand where you scanned before and slowly look around. Turn on a light if it's dark.")
            speak(statusText, key: "recognizing", now: now)
            return
        }
        let light = frame.lightEstimate.map { Float($0.ambientIntensity) }
        let tip = ScanCoach.tip(for: ScanSnapshot(tracking: tracking, mapping: mapping, ambientLight: light))
        setStatus(tip.message)

        if tip.isProblem {
            speak(tip.message, key: tip.kind.rawValue, now: now)
        } else if tip.kind == .areaMapped, now - lastMappedAnnouncement > 30 {
            lastMappedAnnouncement = now
            speak(tip.message, key: tip.kind.rawValue, now: now)
        }
    }

    /// Only publishes real changes, so the screen isn't redrawn ten times a second.
    private func setStatus(_ text: String) {
        if statusText != text { statusText = text }
    }

    private func speak(_ text: String, key: String, urgent: Bool = false, now: TimeInterval) {
        if throttle.shouldSpeak(key: key, urgent: urgent, now: now) {
            speaker.speak(text)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        home.trail.breakTrail()
        speaker.speak("The camera paused.")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        speaker.speak("The camera is back. Look around slowly.")
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        statusText = "The camera stopped: \(error.localizedDescription)"
        speaker.speak(statusText)
        haptics.failure()
    }

    // MARK: - Actions

    /// Speaks the current tip again.
    func repeatStatus() {
        speaker.speak(statusText)
    }

    /// Names the spot where the phone is right now.
    /// - Returns: what happened, already spoken out loud.
    @discardableResult
    func markPlace(named rawName: String) -> Bool {
        guard let name = HomeData.cleanName(rawName) else {
            speaker.speak("The name was empty, so nothing was saved.")
            return false
        }
        guard let position = currentPosition, hasRecognizedHome else {
            speaker.speak("I can't mark this spot right now because I've lost track. Look around slowly and try again.")
            haptics.failure()
            return false
        }
        guard !home.hasPlace(named: name) else {
            speaker.speak("You already have a place called \(name). Pick a different name.")
            haptics.failure()
            return false
        }
        home.trail.pin(at: position)
        home.places.append(Place(name: name, position: position))
        placeCount = home.places.count
        haptics.success()
        speaker.speak("Saved \(name). Keep walking to scan the way to your next place.")
        return true
    }

    /// Saves everything. Calls `completion(true)` once it is safely stored.
    func save(completion: @escaping (Bool) -> Void) {
        guard !isSaving else { return }
        guard hasRecognizedHome else {
            speaker.speak("I haven't recognized your home yet, so there's nothing new to save. Look around slowly first.")
            completion(false)
            return
        }
        guard !home.places.isEmpty else {
            speaker.speak("Mark at least one place before saving, for example your kitchen.")
            completion(false)
            return
        }
        guard ScanCoach.canSave(mapping) else {
            speaker.speak("There isn't enough mapped yet. Keep walking slowly and look around, then try again.")
            completion(false)
            return
        }

        isSaving = true
        speaker.speak("Saving your home.")
        session.getCurrentWorldMap { [weak self] map, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                guard let map else {
                    self.speaker.speak("Saving didn't work. Keep scanning for a moment and try again.")
                    self.haptics.failure()
                    completion(false)
                    return
                }
                do {
                    try self.store.save(home: self.home, worldMap: map)
                    self.haptics.success()
                    let count = self.home.places.count
                    self.speaker.speak("Saved. Your home has \(count) \(count == 1 ? "place" : "places").")
                    completion(true)
                } catch {
                    self.speaker.speak("Saving didn't work: \(error.localizedDescription)")
                    self.haptics.failure()
                    completion(false)
                }
            }
        }
    }
}
