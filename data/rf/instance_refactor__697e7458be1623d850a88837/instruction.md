The `DeadLetterEventSource` in `events/event_source.py` has a race condition when multiple runners are active. Currently, the `run` method fetches dead letter events and immediately passes them to the callback without claiming ownership, so two runners can process the same event at the same time. On top of that, `SyncEvent.mark_as_taken()` in `app/models.py` only works for events with a NULL `taken_time`, which means events that were previously claimed by a stalled or crashed runner get stuck forever and are never retried.

Can you fix both of these issues? The dead letter source should claim each event before processing it, and only process events it successfully claimed. The event processing logic should also be separated from the infinite loop so it can be called and tested on its own. The `mark_as_taken` method should be able to handle not just unclaimed events but also events that have been sitting in a taken state for too long, while still preserving its current behavior for existing callers that do not need that capability.

We also need a oneshot backfill script at `oneshot/send_plan_change_events.py` to re-sync plan data with partners. It should go through `PartnerUser` records in batches, check each user's active subscription end time (excluding partner subscriptions), and fire a `UserPlanChanged` event with the appropriate plan end time. It should support command line arguments for the PartnerUser ID range and print progress as it runs.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

\- Path: `app/models.py`
- Name: `SyncEvent.mark_as_taken`
- Type: method
- Input: `self, allow_taken_older_than: Optional[Arrow] = None`
- Output: `bool`
- Description: Attempts to claim a sync event by updating its taken_time. Returns True if the event was successfully claimed. When allow_taken_older_than is provided, also claims events whose taken_time is older than the given threshold.

\- Path: `events/event_source.py`
- Name: `DeadLetterEventSource.execute_loop`
- Type: method
- Input: `self, on_event: Callable[[SyncEvent], NoReturn]`
- Output: `list[SyncEvent]`
- Description: Performs a single iteration of dead letter processing. Fetches dead letter events, claims each one before dispatching, and returns the list of fetched events.
