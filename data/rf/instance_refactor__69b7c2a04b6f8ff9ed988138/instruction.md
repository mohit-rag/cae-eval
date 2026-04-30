The netdata daemon has several crash handling issues across startup, runtime, and shutdown.

During startup in `src/daemon/main.c`, the signal handler installs too late, after many operations that can themselves crash. Crashes during early steps like environment setup or web server socket binding go completely undiagnosed. Signal handling needs to be active much earlier. The startup timing is also too coarse, lumping multiple operations under generic labels like "initialize environment", so when a crash does happen it is impossible to tell which operation was responsible. These need to be split into finer-grained steps. On a related note, when web server socket setup fails, the daemon calls `exit(1)` directly instead of going through the fatal path, so the failure never gets recorded in the status file.

Exit reason tracking is inconsistent. Some crash paths directly OR into the global `exit_initiated` variable while others (like out-of-memory) do not record a reason at all. This should be centralized through a dedicated function. The status file version should be bumped to reflect this change.

The log subsystem has two fatal-related callback registration functions whose names do not convey which one captures event data and which one triggers the final cleanup. These need clearer names, with all internal fields and call sites updated.

The shutdown watcher still references obsolete steps `WATCHER_STEP_ID_CREATE_SHUTDOWN_FILE` and `WATCHER_STEP_ID_DBENGINE_EXIT_MODE` that should be removed. The shutdown sequence also does not signal or wait for the systemd service to stop. The systemd D-Bus event listener itself can crash if the bus becomes NULL, and does not handle signal interruptions in the wait loop gracefully.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `src/libnetdata/exit/exit_initiated.c`
- Name: `exit_initiated_add`
- Type: function
- Input: `EXIT_REASON reason`
- Output: `void`
- Description: Accumulates an exit reason into the global exit state by combining it with any previously recorded reasons. Used by crash paths that need to record why the daemon is exiting without triggering the full exit sequence.

- Path: `src/libnetdata/log/nd_log.c`
- Name: `nd_log_register_fatal_data_cb`
- Type: function
- Input: `log_event_t cb`
- Output: `void`
- Description: Registers the callback that captures fatal event data (filename, function, message, errno string, stack trace, line number) when a fatal error occurs. Replaces the former `nd_log_register_event_cb`.

- Path: `src/libnetdata/log/nd_log.c`
- Name: `nd_log_register_fatal_final_cb`
- Type: function
- Input: `fatal_event_t cb`
- Output: `void`
- Description: Registers the callback that performs the final action after a fatal error has been logged (typically cleanup and exit). Replaces the former `nd_log_register_fatal_cb`.
