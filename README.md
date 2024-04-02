# DistributedTracer

My "Stupid tricks with Distributed Tracing" - generating traces from XCTest cases.

I shoved this together, wrapping the amazing work of [Moritz Lang](https://github.com/slashmo)'s [swift-otel](https://github.com/slashmo/swift-otel) package, so that I could 
instrument a library using [Swift Distributed Tracing](https://github.com/apple/swift-distributed-tracing) - and see the traces from running tests locally.

It's admittedly a hack-job, needed because some of the libraries around tracing infrastructure can only be initialized once per process. 
To accommodate that constraint, I've set this up as a global actor that you access through a `shared` instance,
and you have to call the async method `bootstrap()` on it, passing in a name for the "service" you're bootstrapping.
You can call that `bootstrap()` method as many times as you like, but it only really works the first time.
Since tests can be run in any order (and you generally want that), I call `bootstrap` in an async setup function.

For example, using `XCTest`, the general structure looks like:

```swift
final class SomeTestSuite: XCTestCase {
    override func setUp() async throws {
        await TestTracer.shared.bootstrap(serviceName: "TestService")
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
        ...
    }
}
```    

## Seeing it

To spin up a Jaeger trace collector:

```
docker-compose up -d
```

Run [the tests from this package](https://github.com/heckj/DistributedTracer/blob/main/Tests/DistributedTracerTests/DistributedTracerTests.swift) to generate a few tests:

```
swift test
```

Open up a browser to see any traces generated to [http://localhost:16686/](http://localhost:16686/), which accesses the Jaeger running in Docker.

## Possible Future Work

I have some hare-brained ideas about using this further, and definitely trying it out with [swift-testing](https://github.com/apple/swift-testing) once that gets a little easier.
In general, I would really like to be able to both export spans from tests, and - in the case of an integration test specifically - be able to retrieve them after the actions of the integration test(s) are complete in order to assert/validation against them.

The other possibility that seems super-interesting to me is enabling tracing from Apple native-platform apps (iOS, macOS, etc) that works in concert with back-end tracing.
There are significantly more challenges there, among which are:
- making sure there's some representation of privacy if you use such a library - privacy manifests, etc
- coordinating capturing traces with backend infrastructure (in large environments, there are too many traces to rationally keep, so you sample them - but ideally you want the samples to be matched between these disparate tracing collection sites. The idea is talked about in distributed tracing circles as 'tail sampling')
- tuning the amount of data captured, and enabling a transport to get them to your back-end infrastructure (basically, don't bloat memory and die, and try to reliably transmit this stuff so you don't loose "the good stuff")
- coming up with an way to ingest into your back-end services in a way that doesn't open up a monstrous security hole that would allow someone to denial-of-service your diagnostics/observability infrastructure.     

If any of this sounds super-interesting to you, let me know - or jump in and contribute here if you like.
And if you want something like this for your company... let me know.
I'm available freelance, and we can work out a means to add the feature or capabilities to this (or other) open-source projects to support the things we like to use.
