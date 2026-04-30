The crash report deduplication logic in Netdata's daemon status file system is too simplistic and misses important context.

Currently, when the daemon restarts after a crash, it decides whether to post a crash report by checking if the previous session's status was DAEMON_STATUS_INITIALIZING and whether it was posted less than 24 hours ago. This means two completely different crashes (different error messages, different stack traces, different root causes) get incorrectly suppressed if they both happen during initialization within a day. At the same time, identical crashes that happen in different daemon states (running vs. exiting) are never deduplicated, producing duplicate reports for the same underlying problem. The dedup data in the status file only stores the previous status and exit reason, which is not enough information to distinguish meaningfully between different crash scenarios.

Can you refactor the deduplication to be content-aware, so that it identifies duplicate crashes based on what actually happened rather than just comparing the daemon state? The system should be able to tell whether the current crash is genuinely the same as the last reported one by considering the full crash context, including fatal error details, the crash message, cause, and other relevant status fields. The dedup information persisted in the status file should reflect this new approach and also track how many times the daemon has restarted. The status file version should be bumped to reflect the schema change, and the JSON parser should handle both old and new format versions gracefully.

Additionally, the fatal error reporting pipeline does not currently capture errno information. The entire chain from the logging callback through the status file registration should be updated to propagate and store errno alongside the other fatal error fields (filename, function, message, stack trace, line). This errno context should be included in the status file JSON and factored into the dedup logic.

The verify_required_directory function in src/daemon/environment.c produces fatal error messages that lack context about which environment variable is associated with the failing directory. These messages should include the environment variable name so that crash reports are easier to diagnose. The manual strerror(errno) calls in these messages are also redundant since the logging system captures errno automatically, so they should be removed.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `src/daemon/daemon-status-file.h`
  - Name: `daemon_status_file_register_fatal`
  - Type: function
  - Input: `const char *filename, const char *function, const char *message, const char *errno_str, const char *stack_trace, long line`
  - Output: `void`
  - Description: Registers fatal error information into the daemon status file. Stores the filename, function, message, errno string, stack trace, and line number. If fatal information has already been registered, frees the incoming strings and returns without overwriting.

- Path: `src/libnetdata/log/nd_log.h`
  - Name: `log_event_t`
  - Type: function
  - Input: `const char *filename, const char *function, const char *message, const char *errno_str, const char *stack_trace, long line`
  - Output: `void`
  - Description: Function pointer typedef for receiving fatal log event information. Called by the logging system when a fatal event occurs, passing the source filename, function name, message, errno string, stack trace, and line number.

- Path: `src/libnetdata/log/nd_log-internals.h`
  - Name: `log_field_strdupz`
  - Type: function
  - Input: `struct log_field *lf`
  - Output: `const char *`
  - Description: Extracts a string representation from a log field entry, duplicating it into a newly allocated string. Returns NULL if the field is unset.
