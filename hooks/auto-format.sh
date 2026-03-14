#!/bin/sh
# Claude Code hook: Auto-format files after edit.
# Event: PostToolUse  Matcher: Edit|Write
# Detects project formatter and runs it on the edited file.
# Silent on failure — never blocks Claude.

_input=$(cat)
_path=$(printf '%s' "$_input" | jq -r '.tool_input.file_path // ""')
[ -z "$_path" ] && exit 0
[ -f "$_path" ] || exit 0

_ext="${_path##*.}"
_dir="${_path%/*}"

# Walk up to find project root (stop at home or filesystem root)
_find_project_root() {
    _d="$1"
    while [ "$_d" != "/" ] && [ "$_d" != "$HOME" ]; do
        if [ -f "$_d/package.json" ] || [ -f "$_d/pyproject.toml" ] || \
           [ -f "$_d/setup.cfg" ] || [ -f "$_d/go.mod" ] || \
           [ -f "$_d/.clang-format" ] || [ -f "$_d/.git" ] || [ -d "$_d/.git" ]; then
            printf '%s' "$_d"
            return 0
        fi
        _d="${_d%/*}"
    done
    return 1
}

_root=$(_find_project_root "$_dir") || exit 0

# Priority 1: Prettier
case "$_ext" in
    js|ts|tsx|jsx|css|json|md)
        set -- "$_root"/.prettierrc*
        if [ -f "$1" ]; then
            _has_prettier=1
        elif [ -f "$_root/package.json" ] && jq -e '.dependencies.prettier // .devDependencies.prettier' "$_root/package.json" >/dev/null 2>&1; then
            _has_prettier=1
        else
            _has_prettier=0
        fi
        if [ "$_has_prettier" = "1" ]; then
            command -v npx >/dev/null 2>&1 || exit 0
            (cd "$_root" && npx prettier --write "$_path" >/dev/null 2>&1) || true
            exit 0
        fi
        ;;
esac

# Priority 2: Black
case "$_ext" in
    py)
        if [ -f "$_root/pyproject.toml" ] || [ -f "$_root/setup.cfg" ]; then
            command -v black >/dev/null 2>&1 || exit 0
            black --quiet "$_path" 2>/dev/null || true
            exit 0
        fi
        ;;
esac

# Priority 3: gofmt
case "$_ext" in
    go)
        command -v gofmt >/dev/null 2>&1 || exit 0
        gofmt -w "$_path" 2>/dev/null || true
        exit 0
        ;;
esac

# Priority 4: clang-format
case "$_ext" in
    c|cpp|h|hpp)
        if [ -f "$_root/.clang-format" ]; then
            command -v clang-format >/dev/null 2>&1 || exit 0
            clang-format -i "$_path" 2>/dev/null || true
            exit 0
        fi
        ;;
esac

exit 0
