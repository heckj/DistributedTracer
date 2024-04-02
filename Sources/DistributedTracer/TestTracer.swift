import Foundation
import Logging
import OTel
import OTLPGRPC
import ServiceLifecycle
import Tracing

@globalActor
public actor TestTracer {
    private var bootstrapped = false
    public static let shared = TestTracer()

    // exposing the tracer so that test shutdown methods can get ahold of it
    // and invoke a flush of the traces before the test execution is summarily
    // terminated.
    public var tracer: (any Tracer)?
    

    func createTracer(serviceName: String) async -> ServiceGroup {
        let environment = OTelEnvironment.detected()
        let resourceDetection = OTelResourceDetection(detectors: [
            OTelProcessResourceDetector(),
            OTelEnvironmentResourceDetector(environment: environment),
            .manual(OTelResource(attributes: ["service.name": "\(serviceName)"])),
        ])
        let resource = await resourceDetection.resource(environment: environment, logLevel: .trace)

        /*
         Bootstrap the logging system to use the OTel metadata provider.
         This will automatically include trace and span IDs in log statements
         from your app and its dependencies.
         */
        LoggingSystem.bootstrap({ label, _ in
            var handler = StreamLogHandler.standardOutput(label: label)
            // We set the lowest possible minimum log level to see all log statements.
            handler.logLevel = .trace
            return handler
        }, metadataProvider: .otel)
        let logger = Logger(label: "example")

        /*
         Here we create an OTel span exporter that sends spans via gRPC to an OTel collector.
         */
        let exporter = try! OTLPGRPCSpanExporter(configuration: .init(environment: environment))
        /*
         This exporter is passed to a batch span processor.
         The processor receives ended spans from the tracer, batches them up, and finally forwards them to the exporter.
         */
        let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: environment))
        /*
         We need to await tracer initialization since the tracer needs
         some time to detect attributes about the resource being traced.
         */
        let myTracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: processor,
            environment: environment,
            resource: resource
        )
        /*
         Once we have a tracer, we bootstrap the instrumentation system to use it.
         This configures your application code and any of your dependencies to use the OTel tracer.
         */
        InstrumentationSystem.bootstrap(myTracer)
        
        let serviceGroup = ServiceGroup(
            services: [myTracer],
            gracefulShutdownSignals: [.sigint],
            logger: logger
        )

        return serviceGroup
    }
    
    // original, hack it into place mechanism - just run something in a detached task in the background.
    // yeah, kind of ugly
    public func bootstrap(serviceName: String) async {
        if !bootstrapped {
            let serviceGroup = await self.createTracer(serviceName: serviceName)

            // Set up a detached task to run this in the background indefinitely.
            // - no cancellation, just GO
            Task {
                try await serviceGroup.run()
            }

            bootstrapped = true
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) // for TaskLocal ServiceContext
    public static func withTracer(
        _ serviceName: String,
        _ operation: () async throws -> ()
    ) async rethrows -> () {
        let serviceGroup = await shared.createTracer(serviceName: serviceName)
        
        return try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask {
                try await serviceGroup.run() // !important
            }

            // So it turns out this idea is illegal, because we're running the operation (our test code)
            // where it's trying to set a TaskLocal variable, which apparently isn't kosher.
            // Per the error when I run a test using this:
            //
            //Thread 2: error: task-local: detected illegal task-local value binding at Tracing/TracerProtocol+Legacy.swift:330.
            //Task-local values must only be set in a structured-context, such as: around any (synchronous or asynchronous function invocation), around an 'async let' declaration, or around a 'with(Throwing)TaskGroup(...){ ... }' invocation. Notably, binding a task-local value is illegal *within the body* of a withTaskGroup invocation.
            //
            //The following example is illegal:
            //
            //    await withTaskGroup(...) { group in
            
            try await operation()
            
            // IDEA: we don't have direct access to tracer here, or it's components, but it
            // could be an interesting idea to capture the spans in this area, not externally
            // publishing them, and then making them available to a test to inspect, assert
            // against, etc.
            //
            // In that case, the wrapping method would return some data structure with spans
            // embedded within it...

            // To shutdown the tracer, cancel its run method by cancelling the taskGroup.
            taskGroup.cancelAll()
        }
    }
    

    private init() {}
}
