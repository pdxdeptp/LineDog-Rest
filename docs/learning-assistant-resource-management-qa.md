# Learning Assistant Resource Management QA

Manual QA for `make-resource-progress-manageable`.

## Setup

1. Start MalDaze from this checkout.
2. Ensure the learning assistant backend is ready.
3. Add or keep at least one active learning resource with a valid `http` or `https` URL.
4. Open the MalDaze panel and switch to `资料进度`.

## Checks

### Open Resource

1. On a resource with a valid URL, click the open-resource action.
2. Verify the source page opens in the system browser.
3. For a resource without a URL, verify the open action is disabled or unavailable.

### Adjust Plan

1. Click the adjust-plan action on a resource.
2. Verify the panel switches to `调整计划`.
3. Verify the chat input is prefilled with the resource title and resource ID.
4. Edit the prompt before sending to confirm the draft is user-editable.

### Mark Complete

1. In `资料进度`, click the mark-complete action on an active resource.
2. Verify the action cannot be triggered repeatedly while it is in flight.
3. Verify the dashboard/resources refresh after success.
4. Verify the completed resource no longer appears in the active resource list.
5. Verify today's tasks no longer show unfinished work for that completed resource.

### Remove From Active Plan

1. In `资料进度`, click the remove-from-plan action on an active resource.
2. Verify the action cannot be triggered repeatedly while it is in flight.
3. Verify the dashboard/resources refresh after success.
4. Verify the archived resource no longer appears in the active resource list.
5. Verify today and future unfinished tasks for that resource no longer appear.

### Failure State

1. Stop or interrupt the backend, then trigger a resource management action.
2. Verify the existing resource list remains visible.
3. Verify an error banner appears and can be cleared.
