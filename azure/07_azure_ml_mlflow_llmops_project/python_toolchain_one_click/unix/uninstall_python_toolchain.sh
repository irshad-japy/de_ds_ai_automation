#!/usr/bin/env bash
# One-click Unix toolchain uninstaller
# Removes the toolchain created by install_python_toolchain_unix.sh:
# Poetry + pyenv-managed Python 3.12.9 + user-level pyenv + managed shell config.

set -u

PYTHON_VERSION="${PYTHON_VERSION:-3.12.9}"
DEFAULT_PYENV_ROOT="$HOME/.pyenv"
POETRY_BIN_DIR="${POETRY_BIN_DIR:-$HOME/.local/bin}"
MARKER_BEGIN="# >>> python-toolchain-one-click >>>"
MARKER_END="# <<< python-toolchain-one-click <<<"

status() { printf '[STATUS] %s\n' "$*"; }
warn()   { printf '[WARN] %s\n' "$*" >&2; }

printf '%s\n' '========================================='
printf '%s\n' ' Starting Unix Uninstall Process'
printf '%s\n' '========================================='

# Make a user-level pyenv available in this shell if it exists.
if [ -x "$DEFAULT_PYENV_ROOT/bin/pyenv" ]; then
    export PYENV_ROOT="$DEFAULT_PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
fi

# -------------------------------------------------------
# 1. Uninstall Poetry
# -------------------------------------------------------
PY_FOR_POETRY=""
if command -v pyenv >/dev/null 2>&1; then
    if pyenv versions --bare 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$PYTHON_VERSION"; then
        candidate="$(pyenv prefix "$PYTHON_VERSION" 2>/dev/null)/bin/python"
        [ -x "$candidate" ] && PY_FOR_POETRY="$candidate"
    fi
fi

if [ -z "$PY_FOR_POETRY" ]; then
    if command -v python3 >/dev/null 2>&1; then
        PY_FOR_POETRY="$(command -v python3)"
    elif command -v python >/dev/null 2>&1; then
        PY_FOR_POETRY="$(command -v python)"
    fi
fi

POETRY_PRESENT=0
command -v poetry >/dev/null 2>&1 && POETRY_PRESENT=1
[ -e "$POETRY_BIN_DIR/poetry" ] && POETRY_PRESENT=1
[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/pypoetry" ] && POETRY_PRESENT=1
[ -d "$HOME/Library/Application Support/pypoetry" ] && POETRY_PRESENT=1

if [ "$POETRY_PRESENT" -eq 1 ] && [ -n "$PY_FOR_POETRY" ] && command -v curl >/dev/null 2>&1; then
    status "Found Poetry installation. Running the official Poetry uninstaller..."
    installer="$(mktemp "${TMPDIR:-/tmp}/install-poetry.XXXXXX.py" 2>/dev/null || printf '%s/install-poetry-%s.py' "${TMPDIR:-/tmp}" "$$")"
    if curl -fsSL https://install.python-poetry.org -o "$installer"; then
        "$PY_FOR_POETRY" "$installer" --uninstall --yes >/dev/null 2>&1 || \
            warn "Official Poetry uninstaller returned an error; fallback cleanup will continue."
    else
        warn "Could not download the Poetry uninstaller; fallback cleanup will continue."
    fi
    rm -f "$installer" 2>/dev/null || true
else
    status "No healthy Poetry installation found, or no Python/curl available. Using local cleanup."
fi

status "Removing lingering Poetry files..."
rm -f "$POETRY_BIN_DIR/poetry" 2>/dev/null || true
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/pypoetry" 2>/dev/null || true
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/pypoetry" 2>/dev/null || true
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/pypoetry" 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/pypoetry" 2>/dev/null || true
rm -rf "$HOME/Library/Caches/pypoetry" 2>/dev/null || true

# -------------------------------------------------------
# 2. Uninstall Python 3.12.9 from pyenv
# -------------------------------------------------------
if command -v pyenv >/dev/null 2>&1; then
    status "Checking for Python $PYTHON_VERSION inside pyenv..."
    if pyenv versions --bare 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$PYTHON_VERSION"; then
        status "Uninstalling Python $PYTHON_VERSION via pyenv..."
        pyenv uninstall -f "$PYTHON_VERSION" >/dev/null 2>&1 || \
            rm -rf "$(pyenv root)/versions/$PYTHON_VERSION" 2>/dev/null || true
    else
        status "Python $PYTHON_VERSION was not found in pyenv. Skipping..."
    fi
else
    status "pyenv command not found. Skipping pyenv Python uninstall command."
fi

# -------------------------------------------------------
# 3. Remove user-level pyenv installation
# -------------------------------------------------------
if [ -d "$DEFAULT_PYENV_ROOT" ]; then
    status "Removing user-level pyenv installation directory: $DEFAULT_PYENV_ROOT"
    rm -rf "$DEFAULT_PYENV_ROOT"
else
    status "User-level pyenv directory was not found. Skipping..."
fi

# -------------------------------------------------------
# 4. Remove only the shell configuration block added by our installer
# -------------------------------------------------------
remove_managed_block() {
    file="$1"
    [ -f "$file" ] || return 0
    tmp="${file}.python_toolchain_tmp.$$"
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip       { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

status "Cleaning managed shell PATH/pyenv configuration..."
remove_managed_block "$HOME/.bashrc"
remove_managed_block "$HOME/.bash_profile"
remove_managed_block "$HOME/.bash_login"
remove_managed_block "$HOME/.profile"
remove_managed_block "$HOME/.zshrc"
remove_managed_block "$HOME/.zprofile"

printf '%s\n' '========================================='
printf '%s\n' ' Uninstallation Completed!'
printf '%s\n' ' Please open a NEW terminal/IDE.'
printf '%s\n' '========================================='
