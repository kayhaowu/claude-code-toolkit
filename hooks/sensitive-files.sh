#!/bin/sh
# Claude Code hook: Block access to sensitive files.
# Event: PreToolUse  Matcher: Read|Edit|Write
# Exit 2 = block file access (stderr fed back to Claude).
# Bypass: CLAUDE_HOOKS_ALLOW_SENSITIVE=1

[ "${CLAUDE_HOOKS_ALLOW_SENSITIVE:-}" = "1" ] && exit 0

_input=$(cat)
_path=$(printf '%s' "$_input" | jq -r '.tool_input.file_path // ""')
[ -z "$_path" ] && exit 0

_basename=$(basename "$_path")
_blocked=""

# .env files
case "$_basename" in
    .env|.env.*) _blocked=".env file (may contain secrets)" ;;
esac

# Credential/secret files (basename match)
if [ -z "$_blocked" ]; then
    case "$_basename" in
        *credentials*|*secret*|*secrets*) _blocked="filename contains credentials/secret" ;;
    esac
fi

# Key/certificate files
if [ -z "$_blocked" ]; then
    case "$_basename" in
        *.key|*.pem|*.p12|*.pfx) _blocked="private key/certificate file" ;;
    esac
fi

# SSH key files
if [ -z "$_blocked" ]; then
    case "$_basename" in
        id_rsa|id_ed25519|id_ecdsa) _blocked="SSH private key" ;;
    esac
fi

# Sensitive directories
if [ -z "$_blocked" ]; then
    case "$_path" in
        "$HOME/.ssh/"*|"$HOME/.aws/"*|"$HOME/.gnupg/"*) _blocked="sensitive config directory" ;;
        ~/.ssh/*|~/.aws/*|~/.gnupg/*) _blocked="sensitive config directory" ;;
    esac
fi

# Password/token in filename only (not path)
if [ -z "$_blocked" ]; then
    case "$_basename" in
        *password*|*token*) _blocked="filename contains password/token" ;;
    esac
fi

if [ -n "$_blocked" ]; then
    printf 'BLOCKED by sensitive-files: %s\nFile: %s\nBypass: export CLAUDE_HOOKS_ALLOW_SENSITIVE=1\n' "$_blocked" "$_path" >&2
    exit 2
fi

exit 0
