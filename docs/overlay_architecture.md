# Overlay Architecture

NightBuddy uses a single-source-of-truth model for overlay control.

## Single Source of Truth

The only authoritative state is:

`bool filterEnabled`

This value represents whether the filter should be on. All inputs update only
this value:
- App UI toggle
- Notification toggle
- Schedule start/end events

Overlay start/stop must never be triggered directly by those inputs.

## Single Overlay Controller

Overlay start/stop is centralized in a single controller path (see
`AppStateNotifier`), which applies:

```
if (filterEnabled && !isSnoozed) {
  startOverlay();
} else {
  stopOverlay();
}
```

No other code should call overlay start/stop.

## Native State Sync

OverlayService reports the actual running state back to Dart. Dart updates      
`filterEnabled` only from confirmed native state and never from optimistic UI   
assumptions. Snooze is treated as a temporary override of overlay application,  
not a separate overlay trigger.

On app start/resume, the app reconciles `filterEnabled` with the native overlay
state to recover from cases where the overlay remained active after a process
kill or resume.

## Common Mistakes to Avoid

- Calling `OverlayService.startOverlay` or `stopOverlay` from UI widgets.
- Triggering overlay start/stop from notification actions.
- Using schedule time windows to gate manual toggles.
- Introducing additional native entry points that start/stop the overlay.
