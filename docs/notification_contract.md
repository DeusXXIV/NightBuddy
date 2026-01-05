# Notification Contract

The notification toggle is a passive input mechanism.

## Required Behavior

- Sends a single intent/event requesting a filter toggle.
- Never calls overlay start/stop.
- Never tracks or infers overlay state.
- UI updates only from confirmed native overlay state.

## Forbidden

- Calling `OverlayService.startOverlay` or `stopOverlay` from notification code.
- Maintaining a separate ON/OFF state for the notification.
