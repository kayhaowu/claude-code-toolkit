#!/bin/sh
# Claude Code hook: Block dangerous shell commands.
# Event: PreToolUse  Matcher: Bash
# Exit 2 = block command (stderr fed back to Claude).
# Bypass: CLAUDE_HOOKS_ALLOW_DANGEROUS=1

[ "${CLAUDE_HOOKS_ALLOW_DANGEROUS:-}" = "1" ] && exit 0

_input=$(cat)
_cmd=$(printf '%s' "$_input" | jq -r '.tool_input.command // ""')
[ -z "$_cmd" ] && exit 0

_blocked=""

# rm -rf: check each dangerous target individually to handle multi-command strings
# (e.g., "rm -rf node_modules && rm -rf /" must still be caught)
case "$_cmd" in
    *'rm -rf /'*) _blocked="rm -rf targeting root filesystem" ;;
esac
if [ -z "$_blocked" ]; then
    case "$_cmd" in
        *'rm -rf ~'*) _blocked="rm -rf targeting home directory" ;;
    esac
fi
if [ -z "$_blocked" ]; then
    case "$_cmd" in
        *'rm -rf .'[!/]*) ;; # ./something — allow (e.g., rm -rf ./build)
        *'rm -rf . '*|*'rm -rf .;'*|*'rm -rf .') _blocked="rm -rf targeting current directory" ;;
    esac
fi

case "$_cmd" in
    *'git push --force'*)
        case "$_cmd" in
            *'--force-with-lease'*) ;; # safe variant, allow
            *) _blocked="git push --force (use --force-with-lease instead)" ;;
        esac
        ;;
esac

# Case-insensitive SQL check: convert to lowercase for matching
_cmd_lower=$(printf '%s' "$_cmd" | tr '[:upper:]' '[:lower:]')
case "$_cmd_lower" in
    *'drop table'*|*'drop database'*)
        _blocked="SQL destructive operation: DROP TABLE/DATABASE" ;;
esac

case "$_cmd" in
    *'| sh'*|*'| bash'*|*'|sh'*|*'|bash'*)
        case "$_cmd" in
            *curl*|*wget*) _blocked="piping download to shell execution" ;;
        esac
        ;;
esac

case "$_cmd" in
    *'chmod 777'*) _blocked="chmod 777 (overly permissive)" ;;
esac

case "$_cmd" in
    *'> /dev/sd'*|*'>/dev/sd'*) _blocked="writing directly to block device" ;;
esac

case "$_cmd" in
    *'dd '*of=/dev/*) _blocked="dd writing to block device" ;;
esac

case "$_cmd" in
    *mkfs.*) _blocked="filesystem format command" ;;
esac

if [ -n "$_blocked" ]; then
    printf 'BLOCKED by safety-guard: %s\nCommand: %s\nBypass: export CLAUDE_HOOKS_ALLOW_DANGEROUS=1\n' "$_blocked" "$_cmd" >&2
    exit 2
fi

exit 0
