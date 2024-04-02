# DistributedTracer

My "Stupid tricks with Distributed Tracing" - generating traces from XCTest cases.



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

