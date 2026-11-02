import XCTest
@testable import FindWayCore

final class GeometryTests: XCTestCase {
    // ARKit: the camera looks toward -z, x is to the right.
    let facingNorth = Point3(0, 0, -1)

    func testTargetAheadIsZeroDegrees() throws {
        let angle = try XCTUnwrap(Geometry.turnAngle(from: .zero, forward: facingNorth, to: Point3(0, 0, -3)))
        XCTAssertEqual(angle, 0, accuracy: 0.01)
    }

    func testTargetOnTheRightIsPositive() throws {
        let angle = try XCTUnwrap(Geometry.turnAngle(from: .zero, forward: facingNorth, to: Point3(2, 0, 0)))
        XCTAssertEqual(angle, 90, accuracy: 0.01)
    }

    func testTargetOnTheLeftIsNegative() throws {
        let angle = try XCTUnwrap(Geometry.turnAngle(from: .zero, forward: facingNorth, to: Point3(-2, 0, 0)))
        XCTAssertEqual(angle, -90, accuracy: 0.01)
    }

    func testTargetBehind() throws {
        let angle = try XCTUnwrap(Geometry.turnAngle(from: .zero, forward: facingNorth, to: Point3(0, 0, 2)))
        XCTAssertEqual(abs(angle), 180, accuracy: 0.01)
    }

    func testHeightIsIgnored() throws {
        // Phone tilted up a bit, target lower down: still straight ahead.
        let angle = try XCTUnwrap(Geometry.turnAngle(from: Point3(0, 1.4, 0), forward: Point3(0, 0.3, -1), to: Point3(0, 0, -3)))
        XCTAssertEqual(angle, 0, accuracy: 0.01)
    }

    func testPhonePointingAtFloorGivesNoAngle() {
        XCTAssertNil(Geometry.turnAngle(from: .zero, forward: Point3(0, -1, 0), to: Point3(0, 0, -3)))
    }

    func testNormalizeDegrees() {
        XCTAssertEqual(Geometry.normalizeDegrees(270), -90, accuracy: 0.001)
        XCTAssertEqual(Geometry.normalizeDegrees(-270), 90, accuracy: 0.001)
        XCTAssertEqual(Geometry.normalizeDegrees(180), 180, accuracy: 0.001)
    }
}

final class TrailMapTests: XCTestCase {
    func walkLine(_ trail: inout TrailMap, from a: Point3, to b: Point3, steps: Int = 40) {
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            trail.walk(to: a + (b - a) * t)
        }
    }

    func testBreadcrumbsAreSpacedOut() {
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -5))
        // 5 meters at 0.5 m spacing: about 11 breadcrumbs, never one per update.
        XCTAssertGreaterThanOrEqual(trail.count, 10)
        XCTAssertLessThanOrEqual(trail.count, 11)
        XCTAssertEqual(trail.totalLength, 5, accuracy: 0.6)
    }

    func testRouteFollowsWalkedPathAroundCorner() throws {
        // Walk north 4 m, then east 4 m (an L-shaped hallway).
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -4))
        walkLine(&trail, from: Point3(0, 0, -4), to: Point3(4, 0, -4))
        let start = try XCTUnwrap(trail.nearestPoint(to: .zero))
        let goal = try XCTUnwrap(trail.nearestPoint(to: Point3(4, 0, -4)))
        let route = try XCTUnwrap(trail.route(from: start, to: goal))
        // The route must pass the corner, not cut diagonally through the wall.
        let passesCorner = route.contains { Geometry.floorDistance(trail.points[$0], Point3(0, 0, -4)) < 0.3 }
        XCTAssertTrue(passesCorner)
    }

    func testWalkingBackOverAPathJoinsIt() throws {
        // Walk a loop-free out-and-back with a side branch, then come back
        // along the first path: the branch should connect to the start.
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -4))      // hallway
        trail.breakTrail()                                        // camera lost track
        walkLine(&trail, from: Point3(3, 0, -2), to: Point3(0, 0, -2)) // new path ends in the hallway
        let start = try XCTUnwrap(trail.nearestPoint(to: Point3(3, 0, -2)))
        let goal = try XCTUnwrap(trail.nearestPoint(to: .zero))
        XCTAssertNotNil(trail.route(from: start, to: goal), "Paths that meet should be joined")
    }

    func testBrokenTrailDoesNotInventAPath() {
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -3))
        trail.breakTrail()
        walkLine(&trail, from: Point3(5, 0, 0), to: Point3(5, 0, -3))
        let a = trail.nearestPoint(to: .zero)!
        let b = trail.nearestPoint(to: Point3(5, 0, 0))!
        XCTAssertNil(trail.route(from: a, to: b), "Two paths that never touch must stay apart")
    }

    func testParallelPathsOnBothSidesOfAWallStayApart() {
        // Two hallways 0.7 m apart (a wall between them).
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -4))
        trail.breakTrail()
        walkLine(&trail, from: Point3(0.7, 0, 0), to: Point3(0.7, 0, -4))
        let a = trail.nearestPoint(to: .zero)!
        let b = trail.nearestPoint(to: Point3(0.7, 0, 0))!
        XCTAssertNil(trail.route(from: a, to: b))
    }

    func testDifferentFloorsAreNotJoined() {
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(0, 0, -3))
        trail.breakTrail()
        walkLine(&trail, from: Point3(0, 2.8, 0), to: Point3(0, 2.8, -3)) // upstairs, same spot
        let a = trail.nearestPoint(to: .zero)!
        let b = trail.nearestPoint(to: Point3(0, 2.8, 0))!
        XCTAssertNotEqual(a, b)
        XCTAssertNil(trail.route(from: a, to: b))
    }

    func testTrailSurvivesSaving() throws {
        var trail = TrailMap()
        walkLine(&trail, from: .zero, to: Point3(2, 0, -2))
        let home = HomeData(places: [Place(name: "Kitchen", position: Point3(2, 0, -2))], trail: trail)
        let decoded = try HomeData.decode(home.encoded())
        XCTAssertEqual(decoded.trail, trail)
        XCTAssertEqual(decoded.places.first?.name, "Kitchen")
    }
}

final class RoutePlannerTests: XCTestCase {
    func lHallway() -> TrailMap {
        var trail = TrailMap()
        for i in 0...40 { trail.walk(to: Point3(0, 0, -Float(i) / 10)) }       // north 4 m
        for i in 0...40 { trail.walk(to: Point3(Float(i) / 10, 0, -4)) }       // east 4 m
        trail.pin(at: Point3(4, 0, -4))
        return trail
    }

    func testPlanKeepsOnlyTheTurns() throws {
        let route = try RoutePlanner.plan(on: lHallway(), from: .zero, to: Point3(4, 0, -4)).get()
        // Start, the corner, the destination. Maybe one extra on the long legs.
        XCTAssertLessThanOrEqual(route.count, 5)
        XCTAssertTrue(route.contains { Geometry.floorDistance($0, Point3(0, 0, -4)) < 0.3 }, "Corner must be kept")
        XCTAssertEqual(Geometry.floorDistance(route.last!, Point3(4, 0, -4)), 0, accuracy: 0.01)
    }

    func testTooFarFromTrail() {
        let result = RoutePlanner.plan(on: lHallway(), from: Point3(-10, 0, 10), to: Point3(4, 0, -4))
        guard case .failure(.tooFarFromTrail) = result else {
            return XCTFail("Expected tooFarFromTrail, got \(result)")
        }
    }

    func testEmptyTrail() {
        let result = RoutePlanner.plan(on: TrailMap(), from: .zero, to: Point3(1, 0, 0))
        XCTAssertEqual(result, .failure(.noTrail))
    }

    func testProblemsHaveSpokenMessages() {
        for problem in [RouteProblem.noTrail, .tooFarFromTrail(meters: 4), .notConnected] {
            XCTAssertFalse(problem.spokenMessage.isEmpty)
        }
    }
}

final class GuidanceTests: XCTestCase {
    let north = Point3(0, 0, -1)
    let east = Point3(1, 0, 0)

    func testWalkThroughLHallway() throws {
        var engine = GuidanceEngine(waypoints: [Point3(0, 0, -4), Point3(4, 0, -4)])

        // At the start, facing north: corner is straight ahead.
        var update = try XCTUnwrap(engine.update(position: .zero, forward: north))
        XCTAssertEqual(update.direction, .straight)
        XCTAssertEqual(GuidanceEngine.steps(for: update.metersToWaypoint), 6)
        XCTAssertEqual(update.metersToDestination, 8, accuracy: 0.01)

        // Reach the corner, still facing north: now the destination is to the right.
        update = try XCTUnwrap(engine.update(position: Point3(0, 0, -3.6), forward: north))
        XCTAssertTrue(update.reachedWaypoint)
        XCTAssertEqual(update.direction, .right)
        XCTAssertEqual(update.clockHour, 3)

        // Turn and walk east.
        update = try XCTUnwrap(engine.update(position: Point3(2, 0, -4), forward: east))
        XCTAssertEqual(update.direction, .straight)
        XCTAssertFalse(update.arrived)

        // Arrive.
        update = try XCTUnwrap(engine.update(position: Point3(3.6, 0, -4), forward: east))
        XCTAssertTrue(update.arrived)
        XCTAssertEqual(GuidancePhrases.instruction(for: update, destinationName: "Kitchen", useClock: false),
                       "You've arrived at Kitchen.")
    }

    func testDoesNotSkipToAWaypointBehindAWall() throws {
        // Route goes north 3 m, east 1 m, then back south on the other side of a wall.
        // The final point is only 1 m from the start but must not be skipped to.
        var engine = GuidanceEngine(waypoints: [Point3(0, 0, -3), Point3(1, 0, -3), Point3(1, 0, 0)])
        let update = try XCTUnwrap(engine.update(position: Point3(0, 0, -0.2), forward: north))
        XCTAssertEqual(update.waypointIndex, 0)
        XCTAssertEqual(update.direction, .straight)
    }

    func testSkipsAheadWhenAlreadyPartwayAlongTheNextLeg() throws {
        var engine = GuidanceEngine(waypoints: [Point3(0, 0, 0), Point3(0, 0, -6)])
        let update = try XCTUnwrap(engine.update(position: Point3(0.2, 0, -3), forward: north))
        XCTAssertEqual(update.waypointIndex, 1)
    }

    func testDirections() {
        XCTAssertEqual(Direction(turnAngle: 5), .straight)
        XCTAssertEqual(Direction(turnAngle: -30), .slightLeft)
        XCTAssertEqual(Direction(turnAngle: 30), .slightRight)
        XCTAssertEqual(Direction(turnAngle: -90), .left)
        XCTAssertEqual(Direction(turnAngle: 160), .turnAround)
    }

    func testClockHours() {
        XCTAssertEqual(GuidanceEngine.clockHour(for: 0), 12)
        XCTAssertEqual(GuidanceEngine.clockHour(for: 90), 3)
        XCTAssertEqual(GuidanceEngine.clockHour(for: -90), 9)
        XCTAssertEqual(GuidanceEngine.clockHour(for: 180), 6)
        XCTAssertEqual(GuidanceEngine.clockHour(for: 60), 2)
    }

    func testPhrases() throws {
        var engine = GuidanceEngine(waypoints: [Point3(0, 0, -1.0)])
        let update = try XCTUnwrap(engine.update(position: Point3(0, 0, 0), forward: north))
        XCTAssertEqual(GuidancePhrases.instruction(for: update, destinationName: "Door", useClock: false),
                       "Straight ahead, 1 step.")
    }
}

final class ThrottleTests: XCTestCase {
    func testDoesNotRepeatTooOften() {
        var throttle = AnnouncementThrottle(minimumGap: 1.5, repeatAfter: 6)
        XCTAssertTrue(throttle.shouldSpeak(key: "straight", now: 0))
        XCTAssertFalse(throttle.shouldSpeak(key: "straight", now: 2))
        XCTAssertFalse(throttle.shouldSpeak(key: "left", now: 1), "Too soon after the last message")
        XCTAssertTrue(throttle.shouldSpeak(key: "left", now: 2))
        XCTAssertTrue(throttle.shouldSpeak(key: "left", now: 8.1), "Repeats after a while")
    }

    func testUrgentMessagesSkipTheGap() {
        var throttle = AnnouncementThrottle()
        XCTAssertTrue(throttle.shouldSpeak(key: "straight", now: 0))
        XCTAssertTrue(throttle.shouldSpeak(key: "arrived", urgent: true, now: 0.2))
    }
}

final class ScanCoachTests: XCTestCase {
    func testDarkRoom() {
        let tip = ScanCoach.tip(for: ScanSnapshot(tracking: .notEnoughDetail, mapping: .limited, ambientLight: 80))
        XCTAssertEqual(tip.kind, .dark)
        XCTAssertTrue(tip.message.contains("light"))
    }

    func testBlankWall() {
        let tip = ScanCoach.tip(for: ScanSnapshot(tracking: .notEnoughDetail, mapping: .limited, ambientLight: 900))
        XCTAssertEqual(tip.kind, .notEnoughDetail)
    }

    func testMovingTooFast() {
        let tip = ScanCoach.tip(for: ScanSnapshot(tracking: .movingTooFast, mapping: .growing, ambientLight: 900))
        XCTAssertEqual(tip.kind, .slowDown)
        XCTAssertTrue(tip.isProblem)
    }

    func testMappedArea() {
        let tip = ScanCoach.tip(for: ScanSnapshot(tracking: .good, mapping: .mapped, ambientLight: 900))
        XCTAssertEqual(tip.kind, .areaMapped)
        XCTAssertFalse(tip.isProblem)
    }

    func testCanSave() {
        XCTAssertFalse(ScanCoach.canSave(.none))
        XCTAssertFalse(ScanCoach.canSave(.limited))
        XCTAssertTrue(ScanCoach.canSave(.growing))
        XCTAssertTrue(ScanCoach.canSave(.mapped))
    }
}

final class ObstacleTests: XCTestCase {
    func testClearWay() {
        XCTAssertNil(ObstacleDetector().obstacleDistance(in: Array(repeating: 2.5, count: 100)))
    }

    func testChairAhead() throws {
        let depths = Array(repeating: Float(2.5), count: 80) + Array(repeating: Float(0.5), count: 20)
        let d = try XCTUnwrap(ObstacleDetector().obstacleDistance(in: depths))
        XCTAssertEqual(d, 0.5, accuracy: 0.01)
    }

    func testOneNoisyReadingIsIgnored() {
        let depths = Array(repeating: Float(2.5), count: 99) + [0.3]
        XCTAssertNil(ObstacleDetector().obstacleDistance(in: depths))
    }

    func testHandOverSensorIsIgnored() {
        XCTAssertNil(ObstacleDetector().obstacleDistance(in: Array(repeating: 0.05, count: 100)))
    }
}

final class HomeDataTests: XCTestCase {
    func testCleanName() {
        XCTAssertEqual(HomeData.cleanName("  kitchen   sink \n"), "kitchen sink")
        XCTAssertNil(HomeData.cleanName("   "))
    }

    func testDuplicateNamesIgnoreCase() {
        let home = HomeData(places: [Place(name: "Kitchen", position: .zero)])
        XCTAssertTrue(home.hasPlace(named: "kitchen"))
        XCTAssertFalse(home.hasPlace(named: "Bathroom"))
    }
}
