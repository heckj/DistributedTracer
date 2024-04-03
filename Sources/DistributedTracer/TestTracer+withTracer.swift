import Foundation

public extension TestTracer {
    static func withTracer(
        serviceName: String,
        _ operation: @escaping @Sendable () async throws -> Void
    ) async rethrows {
        await withThrowingTaskGroup(of: Void.self) { taskGroup in
            let tracer = TestTracer.createTracer(serviceName: serviceName)

            taskGroup.addTask {
                try await tracer.run()
            }

            taskGroup.addTask {
                try await operation()
            }

            taskGroup.cancelAll()
        }
    }
}
