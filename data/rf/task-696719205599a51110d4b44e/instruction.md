The `Run()` method in `execution/scheduler.go` has grown into a monolith that handles VU initialization, executor setup, AND test execution all in one place. This is causing issues when initialization fails because we have to awkwardly clean up resources that already started within the same function.

The lifecycle should be cleaner. Initialization and execution are conceptually separate phases, but they're tangled together right now. If initialization fails partway through, we need a proper way to clean up what was already started.

Can you separate these concerns? The caller should be able to handle initialization and execution as distinct steps. `Run()` should just handle the actual test execution after initialization is complete. The initialization step should return a cleanup function that the caller can use to properly stop any resources that were started. Make sure `cmd/run.go` works with whatever changes you make.

I've already taken care of all changes to the test files. This means you DON'T have to modify the testing logic or any of the tests in any way!

Your task is to make the minimal changes to non-tests files in the working directory to ensure the task is satisfied.

Use the below Interface:

\- Path: execution/scheduler.go
- Name: Scheduler.Init
- Type: method
- Input: runCtx context.Context, samplesOut chan&lt;- metrics.SampleContainer
- Output: (stopVUEmission func(), err error)
- Description: Concurrently initializes all planned VUs and sequentially initializes all configured executors. Starts measurement and emission of vus and vus_max metrics. Returns a cleanup function to stop metric emission and an error if initialization fails. If the run context is cancelled during initialization, returns the cancellation reason. Automatically calls the cleanup function if initialization fails.