import ARKit
import FindWayCore

/// Recognizes where the person is in their home, then guides them to a saved place
/// with spoken directions, a spatial sound beacon and vibrations.
final class NavigationSession: NSObject, ObservableObject, ARSessionDelegate {
    enum Phase: Equatable {
        case recognizing
        case guiding
        case arrived
        case failed
    }

    struct Options {
        var clockDirections = false
        var obstacleWarnings = true
        var beacon = true
    }

    @Published private(set) var phase: Phase = .recognizing
    @Published private(set) var statusText = "Starting the camera."
    @Published private(set) var detailText = ""

    let destination: Place
    let session = ARSession()

    private let home: HomeData
    private let store: HomeStore
    private let options: Options
    private let speaker = Speaker.shared
    private let haptics = Haptics()
    private let beacon = SpatialBeacon()
    private let obstacles = ObstacleDetector()

    private var engine: GuidanceEngine?
    private var latest: GuidanceUpdate?
    private var throttle = AnnouncementThrottle(minimumGap: 1.5, repeatAfter: 7)
    private var obstacleThrottle = AnnouncementThrottle(minimumGap: 3, repeatAfter: 4)
    private var lastProcessed: TimeInterval = 0
    private var lastObstacleCheck: TimeInterval = 0
    private var startedAt: TimeInterval?
    private var lostSince: TimeInterval?
    private var wasOnCourse = false

    init(store: HomeStore, home: HomeData, destination: Place, options: Options) {
        self.store = store
        self.home = home
        self.destination = destination
        self.options = options
        super.init()
        session.delegate = self
    }

    // MARK: - Start and stop

    func start() {
        guard phase == .recognizing, startedAt == nil else { return }
        let worldMap: ARWorldMap
        do {
            worldMap = try store.loadWorldMap()
        } catch {
            phase = .failed
            setStatus("I couldn't open the saved scan of your home. Try scanning your home again.")
            speaker.speak(statusText)
            haptics.failure()
            return
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.initialWorldMap = worldMap
        if options.obstacleWarnings, ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        statusText = "Look around slowly so I can recognize where you are."
        speaker.speak("Going to \(destination.name). \(statusText)")
    }

    func stop() {
        session.pause()
        beacon.stop()
    }

    // MARK: - Camera updates

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = frame.timestamp
        guard now - lastProcessed >= 0.1 else { return }
        lastProcessed = now
        if startedAt == nil { startedAt = now }

        let tracking = frame.camera.trackingState.condition
        switch phase {
        case .recognizing:
            recognize(frame: frame, tracking: tracking, now: now)
        case .guiding:
            guide(frame: frame, tracking: tracking, now: now)
        case .arrived, .failed:
            break
        }
    }

    private func recognize(frame: ARFrame, tracking: TrackingCondition, now: TimeInterval) {
        guard tracking == .good else {
            let waited = now - (startedAt ?? now)
            if waited > 40 {
                setStatus("I still can't recognize this spot. Turn on a light, or move to a room you scanned, then keep looking around slowly.")
                say(statusText, key: "recognize-hard", now: now)
            } else if waited > 8 {
                setStatus("Still looking. Slowly turn around in place.")
                say(statusText, key: "recognize", now: now)
            }
            return
        }

        let position = frame.camera.transform.position
        switch RoutePlanner.plan(on: home.trail, from: position, to: destination.position) {
        case .success(let waypoints):
            engine = GuidanceEngine(waypoints: waypoints)
            phase = .guiding
            haptics.success()
            if options.beacon {
                beacon.start()
            }
            var probe = GuidanceEngine(waypoints: waypoints)
            if let first = probe.update(position: position, forward: frame.camera.transform.cameraForward) {
                let summary = GuidancePhrases.summary(for: first, destinationName: destination.name)
                setStatus("Found you. \(summary)")
                speaker.speak("Found you. \(summary) Follow the directions\(options.beacon ? " and the ping sound" : "").")
                throttle.reset()
                _ = throttle.shouldSpeak(key: "intro", now: now)
            }
        case .failure(let problem):
            phase = .failed
            setStatus(problem.spokenMessage)
            speaker.speak(problem.spokenMessage)
            haptics.failure()
        }
    }

    private func guide(frame: ARFrame, tracking: TrackingCondition, now: TimeInterval) {
        guard var engine else { return }

        guard tracking == .good else {
            if lostSince == nil { lostSince = now }
            beacon.isMuted = true
            if now - (lostSince ?? now) > 1.5 {
                setStatus("I lost track. Stand still and slowly look around.")
                say(statusText, key: "lost", now: now)
            }
            return
        }
        if lostSince != nil {
            lostSince = nil
            beacon.isMuted = false
        }

        let transform = frame.camera.transform
        let position = transform.position
        let forward = transform.cameraForward

        guard let update = engine.update(position: position, forward: forward) else {
            setStatus("Point the phone forward, not at the floor.")
            say(statusText, key: "tilt", now: now)
            self.engine = engine
            return
        }
        self.engine = engine
        latest = update
        beacon.update(listener: position, forward: forward, target: engine.waypoints[update.waypointIndex])

        if update.arrived {
            phase = .arrived
            beacon.stop()
            haptics.success()
            let message = GuidancePhrases.instruction(for: update, destinationName: destination.name, useClock: false)
            setStatus(message)
            detailText = ""
            speaker.speak(message)
            return
        }

        let instruction = GuidancePhrases.instruction(for: update, destinationName: destination.name, useClock: options.clockDirections)
        setStatus(instruction)
        let detail = GuidancePhrases.summary(for: update, destinationName: destination.name)
        if detailText != detail { detailText = detail }

        // Speak when the direction changes or a waypoint is reached; repeat now and then.
        let key = "\(update.waypointIndex)-\(update.direction)"
        say(instruction, key: key, urgent: update.reachedWaypoint, now: now)

        // A light tap the moment the person turns to face the right way.
        let onCourse = update.direction == .straight
        if onCourse && !wasOnCourse { haptics.onCourse() }
        wasOnCourse = onCourse

        checkObstacles(frame: frame, now: now)
    }

    private func checkObstacles(frame: ARFrame, now: TimeInterval) {
        guard options.obstacleWarnings, now - lastObstacleCheck >= 0.3, let depth = frame.sceneDepth else { return }
        lastObstacleCheck = now
        let depths = DepthSampler.centerDepths(from: depth)
        guard let distance = obstacles.obstacleDistance(in: depths) else { return }
        if obstacleThrottle.shouldSpeak(key: "obstacle", urgent: true, now: now) {
            haptics.warning()
            let steps = distance < 0.5 ? "very close" : "about one step away"
            speaker.speak("Careful, something ahead, \(steps).")
            // Let the next direction be spoken right after the warning.
            throttle.reset()
        }
    }

    // MARK: - Interruptions

    func sessionWasInterrupted(_ session: ARSession) {
        beacon.isMuted = true
        speaker.speak("The camera paused.")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        beacon.isMuted = false
        speaker.speak("The camera is back. Look around slowly.")
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        phase = .failed
        beacon.stop()
        setStatus("The camera stopped: \(error.localizedDescription)")
        speaker.speak(statusText)
        haptics.failure()
    }

    // MARK: - Actions

    /// Says the current direction and how far is left.
    func repeatDirections() {
        guard phase == .guiding, let latest else {
            speaker.speak(statusText)
            return
        }
        let instruction = GuidancePhrases.instruction(for: latest, destinationName: destination.name, useClock: options.clockDirections)
        let summary = GuidancePhrases.summary(for: latest, destinationName: destination.name)
        speaker.speak("\(instruction) \(summary)")
    }

    // MARK: - Helpers

    private func setStatus(_ text: String) {
        if statusText != text { statusText = text }
    }

    private func say(_ text: String, key: String, urgent: Bool = false, now: TimeInterval) {
        if throttle.shouldSpeak(key: key, urgent: urgent, now: now) {
            speaker.speak(text)
        }
    }
}
