# Scheduling Model

Scheduling is event-based, not state-based.

## Event-Based Rules

Scheduling only emits discrete events:

- Schedule start:
  - If `filterEnabled == false`, set `filterEnabled = true`
- Schedule end:
  - If `filterEnabled == true`, set `filterEnabled = false`

Between these events, scheduling does nothing and never checks time windows.

Scheduling does not:
- Continuously evaluate time windows
- Block manual toggles
- Override manual toggles outside of these events

## Wind-Down and Fade-Out

When wind-down or fade-out is enabled, the schedule start/end events are shifted
to the ramp boundaries:

- Start event at `startTime - windDownMinutes`
- End event at `endTime + fadeOutMinutes`

## Example Timelines

Example: Schedule 22:00 to 06:00, wind-down 30m, fade-out 15m.

- 21:30: schedule start event -> enable filter (if not already)
- 06:15: schedule end event -> disable filter (if enabled)

Manual toggle before, during, or after these events is always allowed and is
never blocked by the schedule.
