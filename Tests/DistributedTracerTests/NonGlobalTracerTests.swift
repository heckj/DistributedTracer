import DistributedTracer
import Tracing
import XCTest

final class NonGlobalTracerTests: XCTestCase {

//    override func tearDown() async throws {
//            // Testing does NOT have a polite shutdown waiting for a flush to complete, so
//            // we explicitly give it some extra time here to flush out any spans remaining.
//            try await Task.sleep(for: .milliseconds(100))
//        }
//    }

    func testClosureInvokerTest() async throws {
        try await TestTracer.withTracer(serviceName: "firstTestService") {
            try await withSpan("example span") { span in

                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("EVENT!"))
                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("SECOND EVENT!"))
            }
        }
    }

    func testClosureInvokerTestAgain() async throws {
        try await TestTracer.withTracer(serviceName: "service2") {
            try await withSpan("example span") { span in

                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("EVENT!"))
                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("SECOND EVENT!"))
            }
        }
    }
}
