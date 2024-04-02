import DistributedTracer
import Tracing
import XCTest

final class DistributedTracerTests: XCTestCase {
    
    func testClosureInvokerTest() async throws {
        try await TestTracer.withTracer("testClosureInvokerTest") {
            try await withSpan("example span") { span in
                
                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("EVENT!"))
                try await Task.sleep(for: .milliseconds(50))
                span.addEvent(SpanEvent("SECOND EVENT!"))
            }
        }
    }
}
