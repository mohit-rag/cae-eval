The cache system in `pkg/cache/` uses `any` for all stored and retrieved values. The `Cache` interface in `pkg/cache/cache.go` accepts and returns `any`, and the in-memory implementation in `pkg/cache/memory/memory.go` does the same for all its types, options, and constructors. This means every caller that reads from the cache has to manually type assert the result, which is error prone and produces unnecessary boilerplate. For example, the GitHub source in `pkg/sources/github/github.go` iterates over cached repository values, asserts each one to `string`, and logs an error if the assertion fails, even though the cache only ever stores strings. The GCS source in `pkg/sources/gcs/gcs.go` has a similar pattern with its persistable cache wrapper.

Can you refactor the cache interface and its memory implementation to be generic so the caller specifies what type of value the cache holds at creation time? The cache should store and return the concrete type directly, eliminating the need for type assertions at every call site. All the supporting types and constructors in the memory package should be parameterized as well. Every source that uses the cache, including the GCS persistable cache wrapper and the GitHub filtered repo cache and org cache, should be updated to work with the typed version. Once the values come back as the correct type, any manual type assertion logic in the consumers can be cleaned up.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below Interface:

- Path: `pkg/cache/cache.go`
  - Name: `Cache[T any]`
  - Type: interface
  - Input: NA
  - Output: NA
  - Description: Generic key/value cache interface parameterized by value type T. Methods Set, Get, and Values use T instead of any. Methods Exists, Delete, Clear, Count, Keys, and Contents remain unchanged in their non-T parameters.

- Path: `pkg/cache/memory/memory.go`
  - Name: `Cache[T any]`
  - Type: struct
  - Input: NA
  - Output: NA
  - Description: In-memory cache implementation parameterized by value type T. Implements cache.Cache[T].

- Path: `pkg/cache/memory/memory.go`
  - Name: `CacheOption[T any]`
  - Type: type
  - Input: `*Cache[T]`
  - Output: NA
  - Description: Functional option type for configuring a Cache[T] instance.

- Path: `pkg/cache/memory/memory.go`
  - Name: `CacheEntry[T any]`
  - Type: struct
  - Input: NA
  - Output: NA
  - Description: Represents a single cache entry with a string Key and a value of type T.

- Path: `pkg/cache/memory/memory.go`
  - Name: `New[T any]`
  - Type: function
  - Input: `opts ...CacheOption[T]`
  - Output: `*Cache[T]`
  - Description: Constructs a new in-memory cache with default expiration and purge intervals, accepting optional configuration functions.

- Path: `pkg/cache/memory/memory.go`
  - Name: `NewWithData[T any]`
  - Type: function
  - Input: `data []CacheEntry[T], opts ...CacheOption[T]`
  - Output: `*Cache[T]`
  - Description: Constructs a new in-memory cache pre-populated with the given entries, accepting optional configuration functions.

- Path: `pkg/cache/memory/memory.go`
  - Name: `WithExpirationInterval[T any]`
  - Type: function
  - Input: `interval time.Duration`
  - Output: `CacheOption[T]`
  - Description: Returns a CacheOption that sets the expiration interval for cache items.

- Path: `pkg/cache/memory/memory.go`
  - Name: `WithPurgeInterval[T any]`
  - Type: function
  - Input: `interval time.Duration`
  - Output: `CacheOption[T]`
  - Description: Returns a CacheOption that sets the interval at which expired items are purged.

- Path: `pkg/cache/memory/memory_test.go`
  - Name: `setupBenchmarks`
  - Type: function
  - Input: `b *testing.B`
  - Output: `*Cache[string]`
  - Description: Test helper that creates and populates a Cache[string] with 500,000 entries for benchmark tests.
