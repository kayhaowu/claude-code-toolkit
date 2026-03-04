# Heartbeat Mechanism Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a background heartbeat process that keeps session JSON epoch fresh, so other sessions and the dashboard never falsely show IDLE.

**Architecture:** A standalone `heartbeat.sh` script runs in the background (one per Claude Code session), updating the session JSON every 2 seconds. It is started by a `SessionStart` hook and cleaned up by `SessionEnd` hook + self-monitoring of parent PID.

**Tech Stack:** POSIX shell, jq, Claude Code hooks (SessionStart/SessionEnd)

---

### Task 1: Create heartbeat.sh

**Files:**
- Create: `statusline/heartbeat.sh`

**Step 1: Write the heartbeat script**

Create `statusline/heartbeat.sh` with the following content:

```sh
#!/bin/sh
# Heartbeat daemon for Claude Code session status tracking.
# Keeps session JSON epoch fresh so other sessions/dashboard see WORKING, not IDLE.
#
# Usage: nohup sh heartbeat.sh <claude_code_pid> &
# Started by SessionStart hook, stopped by SessionEnd hook or parent death.

set -e

TARGET_PID="${1:?Usage: heartbeat.sh <pid>}"
SESSIONS_DIR="$HOME/.claude/sessions"
SESSION_FILE="$SESSIONS_DIR/$TARGET_PID.json"
PIDFILE="$SESSIONS_DIR/$TARGET_PID.hb.pid"
INTERVAL=2

# ── Startup guard: prevent duplicate heartbeats ──────────────────────────────
if [ -f "$PIDFILE" ]; then
    existing=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$existing" ] && kill -0 "$existing" 2>/dev/null; then
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# ── Write our PID ────────────────────────────────────────────────────────────
mkdir -p "$SESSIONS_DIR"
echo $$ > "$PIDFILE"

# ── Cleanup on exit ──────────────────────────────────────────────────────────
cleanup() {
    rm -f "$PIDFILE"
    # If parent is dead, remove stale session file too
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        rm -f "$SESSION_FILE"
    fi
}
trap cleanup EXIT INT TERM

# ── Main heartbeat loop ─────────────────────────────────────────────────────
while true; do
    # Exit if parent process is gone
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
        exit 0
    fi

    # Update session JSON if it exists
    if [ -f "$SESSION_FILE" ]; then
        _epoch=$(date +%s)
        _mem=$(ps -o rss= -p "$TARGET_PID" 2>/dev/null | awk '{printf "%d",$1+0}') || _mem=0
        _tmp="$SESSION_FILE.hb.tmp"
        jq --arg epoch "$_epoch" --arg mem "$_mem" \
            '.epoch = ($epoch | tonumber) | .mem_kb = ($mem | tonumber)' \
            "$SESSION_FILE" > "$_tmp" 2>/dev/null && mv "$_tmp" "$SESSION_FILE" \
            || rm -f "$_tmp"
    fi

    sleep "$INTERVAL"
done
```

**Step 2: Verify the script is syntactically valid**

Run: `sh -n statusline/heartbeat.sh`
Expected: No output (no syntax errors)

**Step 3: Commit**

```bash
git add statusline/heartbeat.sh
git commit -m "feat: add heartbeat daemon for session status tracking"
```

---

### Task 2: Update IDLE threshold in statusline-command.sh

**Files:**
- Modify: `statusline/statusline-command.sh:116`

**Step 1: Change threshold from 4 to 6 seconds**

In `statusline/statusline-command.sh`, line 116, change:

```sh
        elif [ "$_oage" -lt 4 ]; then
```

to:

```sh
        elif [ "$_oage" -lt 6 ]; then
```

This gives a 2x heartbeat interval (2s) + 2s buffer = 6s before marking IDLE.

**Step 2: Verify no other references to the old threshold**

Run: `grep -n 'lt 4' statusline/statusline-command.sh`
Expected: No remaining matches

**Step 3: Commit**

```bash
git add statusline/statusline-command.sh
git commit -m "fix: increase IDLE threshold to 6s for heartbeat compatibility"
```

---

### Task 3: Update IDLE threshold in dashboard.sh

**Files:**
- Modify: `statusline/dashboard.sh:111`

**Step 1: Change threshold from 4 to 6 seconds**

In `statusline/dashboard.sh`, line 111, change:

```sh
        elif [ "$age" -lt 4 ]; then
```

to:

```sh
        elif [ "$age" -lt 6 ]; then
```

**Step 2: Verify no other references to the old threshold**

Run: `grep -n 'lt 4' statusline/dashboard.sh`
Expected: No remaining matches

**Step 3: Commit**

```bash
git add statusline/dashboard.sh
git commit -m "fix: increase dashboard IDLE threshold to 6s for heartbeat compatibility"
```

---

### Task 4: Update install.sh to deploy heartbeat + hooks

**Files:**
- Modify: `statusline/install.sh:67-82` (step 4: copy scripts)
- Modify: `statusline/install.sh:84-99` (step 5: merge settings)

**Step 1: Add heartbeat.sh copy to step 4**

After line 76 (`success "Copied to $TARGET_DASHBOARD"`), add:

```sh
info "Installing heartbeat.sh to $CLAUDE_DIR..."
cp "$SCRIPT_DIR/heartbeat.sh" "$CLAUDE_DIR/heartbeat.sh"
chmod +x "$CLAUDE_DIR/heartbeat.sh"
success "Copied to $CLAUDE_DIR/heartbeat.sh"
```

**Step 2: Add TARGET_HEARTBEAT variable**

After line 9 (`TARGET_DASHBOARD="$CLAUDE_DIR/dashboard.sh"`), add:

```sh
TARGET_HEARTBEAT="$CLAUDE_DIR/heartbeat.sh"
```

(And update step 1 copy to use `$TARGET_HEARTBEAT` instead of the inline path.)

**Step 3: Update settings merge to include hooks**

Replace the jq merge command (line 92) to also merge hooks:

```sh
    jq '. * {
        "statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"},
        "hooks": (.hooks // {} | . * {
            "SessionStart": [{"hooks":[{"type":"command","command":"nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"}]}],
            "SessionEnd": [{"hooks":[{"type":"command","command":"sh -c '\''kill $(cat ~/.claude/sessions/$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/$PPID.json ~/.claude/sessions/$PPID.hb.pid'\''"}]}]
        })
    }' "$SETTINGS_BACKUP" > "$SETTINGS_TMP" && mv "$SETTINGS_TMP" "$SETTINGS_FILE"
```

Also update the fresh-install case (line 97) similarly:

```sh
    jq -n '{
        "statusLine":{"type":"command","command":"sh ~/.claude/statusline-command.sh"},
        "hooks":{
            "SessionStart":[{"hooks":[{"type":"command","command":"nohup sh ~/.claude/heartbeat.sh $PPID > /dev/null 2>&1 &"}]}],
            "SessionEnd":[{"hooks":[{"type":"command","command":"sh -c '\''kill $(cat ~/.claude/sessions/$PPID.hb.pid 2>/dev/null) 2>/dev/null; rm -f ~/.claude/sessions/$PPID.json ~/.claude/sessions/$PPID.hb.pid'\''"}]}]
        }
    }' > "$SETTINGS_FILE"
```

**Step 4: Verify install.sh syntax**

Run: `sh -n statusline/install.sh`
Expected: No output (no syntax errors)

**Step 5: Commit**

```bash
git add statusline/install.sh
git commit -m "feat: install heartbeat daemon and hooks via install.sh"
```

---

### Task 5: Manual integration test

**Step 1: Run install.sh**

```bash
sh statusline/install.sh
```

Expected: All steps succeed, heartbeat.sh copied, hooks merged into settings.json

**Step 2: Verify settings.json has hooks**

```bash
jq '.hooks.SessionStart, .hooks.SessionEnd' ~/.claude/settings.json
```

Expected: Both arrays are present with the correct hook commands

**Step 3: Verify heartbeat.sh is installed**

```bash
ls -la ~/.claude/heartbeat.sh
```

Expected: File exists and is executable

**Step 4: Test heartbeat standalone**

```bash
# Start a dummy long-running process
sleep 300 &
DUMMY_PID=$!

# Create a fake session JSON
mkdir -p ~/.claude/sessions
echo '{"pid":'$DUMMY_PID',"epoch":0,"model":"test","project_name":"test","status":"","used_pct":0,"tokens_in":0,"tokens_out":0,"mem_kb":0}' > ~/.claude/sessions/$DUMMY_PID.json

# Start heartbeat
sh ~/.claude/heartbeat.sh $DUMMY_PID &
HB_PID=$!

# Wait 3 seconds, check epoch was updated
sleep 3
jq '.epoch' ~/.claude/sessions/$DUMMY_PID.json
# Expected: recent epoch (within last 2 seconds)

# Kill dummy → heartbeat should self-terminate and clean up
kill $DUMMY_PID
sleep 3
ls ~/.claude/sessions/$DUMMY_PID.json 2>/dev/null && echo "FAIL: file still exists" || echo "PASS: cleaned up"
ls ~/.claude/sessions/$DUMMY_PID.hb.pid 2>/dev/null && echo "FAIL: pidfile still exists" || echo "PASS: pidfile cleaned up"
```

**Step 5: Commit design doc and plan**

```bash
git add docs/plans/2026-03-04-heartbeat-design.md docs/plans/2026-03-04-heartbeat-plan.md
git commit -m "docs: add heartbeat design and implementation plan"
```
