The rate limiting for alias creation in models.py is hardcoded and uses an inconsistent time unit. Limits are in days but rate_limiter.check_bucket_limit expects seconds, so there's an awkward * 86400 conversion.

Can you make this configurable via environment variables instead? I need separate rate limits for free vs paid users, with support for multiple rate windows (like both a short burst limit and a longer rolling limit). If the env var is empty, just skip rate limiting rather than erroring.

I've already taken care of all changes to the test files. This means you DON'T have to modify the testing logic or any of the tests in any way!

Your task is to make the minimal changes to non-tests files in the working directory to ensure the task is satisfied.

Use the below Interface:

- Path: `app/config.py`
- Name: `getRateLimitFromConfig`
- Type: function
- Input: `env_var: str, default: str = ""`
- Output: `list[tuple[int, int]]`
- Description: Parses a rate limit configuration from an environment variable. The format is "hits,seconds:hits,seconds..." (e.g., "1,10:4,60" means 1 hit in 10 seconds or 4 hits in 60 seconds). Returns an empty list if the environment variable is not set or is empty. Raises an exception if the value is set but cannot be parsed (e.g., not in the expected format).

- Path: `app/config.py`
- Name: `ALIAS_CREATE_RATE_LIMIT_FREE`
- Type: constant
- Input: `NA`
- Output: `list[tuple[int, int]]`
- Description: Rate limit configuration for free users when creating aliases. Loaded from the `ALIAS_CREATE_RATE_LIMIT_FREE` environment variable with default value "10,900:50,3600" (10 aliases per 900 seconds, 50 aliases per 3600 seconds).

- Path: `app/config.py`
- Name: `ALIAS_CREATE_RATE_LIMIT_PAID`
- Type: constant
- Input: `NA`
- Output: `list[tuple[int, int]]`
- Description: Rate limit configuration for paid/premium users when creating aliases. Loaded from the `ALIAS_CREATE_RATE_LIMIT_PAID` environment variable with default value "50,900:200,3600" (50 aliases per 900 seconds, 200 aliases per 3600 seconds).