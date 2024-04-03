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

    // hanging on to the handle for the detached task that "runs" the tracer, but not
    // sure if we need to be able to cancel it or not... at least in a test scenario.
    // Since you can only bootstrap instrumentation once, it seems you can't even manipulate
    // or replace a tracer once it's set up (at least with how Distributed Tracing is set up
    // today, so this is private and currently unused.
    private var tracerRunHandle: Task<Void, any Error>?

    static func createTracer(serviceName: String) -> OTelTracer<OTelRandomIDGenerator<SystemRandomNumberGenerator>, OTelConstantSampler, OTelW3CPropagator, OTelBatchSpanProcessor<OTLPGRPCSpanExporter, ContinuousClock>, ContinuousClock> {
        let resource = OTelResource(attributes: ["service.name": "\(serviceName)"])
        let environment = OTelEnvironment.detected()
        // Here we create an OTel span exporter that sends spans via gRPC to an OTel collector.
        let exporter = try! OTLPGRPCSpanExporter(configuration: .init(environment: environment))
        // This exporter is passed to a batch span processor.

        // The processor receives ended spans from the tracer, batches them up, and finally
        // forwards them to the exporter.
        let processor = OTelBatchSpanProcessor(exporter: exporter, configuration: .init(environment: environment))

        let myTracer = OTelTracer(
            idGenerator: OTelRandomIDGenerator(),
            sampler: OTelConstantSampler(isOn: true),
            propagator: OTelW3CPropagator(),
            processor: processor,
            environment: environment,
            resource: resource
        )

        // Once we have a tracer, we bootstrap the instrumentation system to use it.
        // You can only bootstrap an instrument ONCE per process (ref:
        // https://github.com/apple/swift-distributed-tracing/blob/main/Sources/Instrumentation/InstrumentationSystem.swift#L38-L39
        // So this has to hold for all bits using the tracer.
        InstrumentationSystem.bootstrap(myTracer)

        return myTracer
    }

    // original, hack it into place mechanism - just run something in a detached task in the background.
    // yeah, kind of ugly
    public func bootstrap(serviceName: String) async {
        if !bootstrapped {
            let tracer = TestTracer.createTracer(serviceName: serviceName)

            // Set up a detached task to run this in the background indefinitely.
            // - no cancellation, just GO
            tracerRunHandle = Task {
                try await tracer.run()
            }

            self.tracer = tracer
            bootstrapped = true
        }
    }

    private init() {
        // Akin to the Instrumentation system, the Logging
        // system can only be bootstrapped once per process. Since it's orthogonal
        // setup, but used by Tracing, we set it up here in the default initializer.
        LoggingSystem.bootstrap({ label, _ in
            var handler = StreamLogHandler.standardOutput(label: label)
            // We set the lowest possible minimum log level to see all log statements.
            handler.logLevel = .trace
            return handler
        }, metadataProvider: .otel)
        let logger = Logger(label: "TestTracer Setup")
        logger.debug("Logging system initialized")
    }
}
