# Heartbeat Mechanism for Session Status Accuracy

**Date:** 2026-03-04
**Status:** Approved

## Problem

The statusline and dashboard use a file-age heuristic (4-second timeout) to determine if a session is WORKING or IDLE. Since `statusline-command.sh` is only called during UI renders, sessions appear IDLE during long processing periods (thinking, tool execution) when no UI updates occur.

## Solution

Introduce a background heartbeat process that updates the session JSON file every 2 seconds, keeping the epoch fresh regardless of UI activity.

## Architecture

```
SessionStart hook
  └→ nohup sh ~/.claude/heartbeat.sh $PPID &
       └→ Every 2s:
           1. kill -0 $PID → confirm parent alive
           2. Read existing session JSON
           3. Rewrite with updated epoch, mem_kb
           4. Write back to $SESSIONS_DIR/$PID.json
       └→ Parent dies → cleanup JSON + pidfile → exit

SessionEnd hook (graceful cleanup)
  └→ kill heartbeat process via pidfile
  └→ rm session JSON + pidfile
```

## New Files

### `statusline/heartbeat.sh`

- **Argument:** `$1` = Claude Code PID to monitor
- **PID file:** `$SESSIONS_DIR/$1.hb.pid` (prevents duplicate heartbeats)
- **Interval:** 2 seconds
- **On each tick:**
  1. `kill -0 $PID` — exit if parent dead
  2. Read existing `$SESSIONS_DIR/$PID.json`
  3. Update `epoch` to current timestamp
  4. Update `mem_kb` via `ps -o rss=`
  5. Write back atomically (write to .tmp then mv)
- **Startup guard:** If pidfile exists and process alive, exit immediately
- **Cleanup on exit:** Remove pidfile; remove session JSON if parent is dead

## Modified Files

### `statusline/statusline-command.sh`

- Change IDLE threshold from `4` to `6` seconds (line 116)
  - 2x heartbeat interval (2s) + 2s buffer = 6s
- Same change in dashboard other-session display (line 111 equivalent)

### `statusline/dashboard.sh`

- Change IDLE threshold from `4` to `6` seconds (line 111)

### `statusline/install.sh`

- Copy `heartbeat.sh` to `~/.claude/heartbeat.sh`
- Merge hooks into `settings.json`:
  ```json
  {
    "hooks": {
      "SessionStart": [
        {
          "type": "command",
          "command": "nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"
        }
      ],
      "SessionEnd": [
        {
          "type": "command",
          "command": "sh -c 'kill $(cat ~/.claude/sessions/$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/$PPID.json ~/.claude/sessions/$PPID.hb.pid'"
        }
      ]
    }
  }
  ```

## Status Determination Logic

No logic change, only threshold adjustment:

```sh
# Before: age < 4 → WORKING
# After:  age < 6 → WORKING (2x heartbeat interval + 2s buffer)
```

With heartbeat running every 2s, the epoch is always fresh, so active sessions will never hit the 6s threshold. Only truly stopped sessions (where heartbeat has also exited) will show as IDLE.

## Design Decisions

1. **Hook lifecycle** over self-starting: Clean start/stop, no orphan processes
2. **2-second interval**: Matches dashboard refresh rate, negligible CPU cost
3. **Full JSON rewrite** on each tick: Keeps mem_kb current, simple implementation
4. **Atomic writes** (tmp + mv): Prevents partial reads by statusline/dashboard
5. **Independent script**: Easy to test, debug, and maintain separately
