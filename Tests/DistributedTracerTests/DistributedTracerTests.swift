import DistributedTracer
import Tracing
import XCTest

final class DistributedTracerTests: XCTestCase {
    override func setUp() async throws {
        await TestTracer.shared.bootstrap(serviceName: "TracerTests")
    }

    override func tearDown() async throws {
        if let tracer = await TestTracer.shared.tracer {
            tracer.forceFlush()
            // Testing does NOT have a polite shutdown waiting for a flush to complete, so
            // we explicitly give it some extra time here to flush out any spans remaining.
            try await Task.sleep(for: .milliseconds(100))

            // This would be a whole lot better at the tail end of the entire suite, or at least
            // at the class tearDown, but `override class func tearDown` doesn't appear to have
            // an async callback where we can do cleanup/flush work like this, so it's in
            // each test execution. Sorry about that.
        }
    }

    func testClosureInvokerTest() async throws {
        try await withSpan("example span") { span in

            try await Task.sleep(for: .milliseconds(50))
            span.addEvent(SpanEvent("EVENT!"))
            try await Task.sleep(for: .milliseconds(50))
            span.addEvent(SpanEvent("SECOND EVENT!"))
        }
    }

    func testClosureInvokerTestAgain() async throws {
        try await withSpan("example span") { span in

            try await Task.sleep(for: .milliseconds(50))
            span.addEvent(SpanEvent("EVENT!"))
            try await Task.sleep(for: .milliseconds(50))
            span.addEvent(SpanEvent("SECOND EVENT!"))
        }
    }
}
