#!/usr/bin/env bash
# One-click Unix toolchain installer
# Installs/reuses: pyenv + Python 3.12.9 + Poetry
# Supported shells for persistent setup: Bash and Zsh
# Supported platforms: Linux, WSL, macOS, and common Unix-like systems with Bash.

set -Eeuo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12.9}"
DEFAULT_PYENV_ROOT="$HOME/.pyenv"
POETRY_BIN_DIR="${POETRY_BIN_DIR:-$HOME/.local/bin}"
MARKER_BEGIN="# >>> python-toolchain-one-click >>>"
MARKER_END="# <<< python-toolchain-one-click <<<"

status() { printf '[STATUS] %s\n' "$*"; }
warn()   { printf '[WARN] %s\n' "$*" >&2; }
fail()   { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

printf '%s\n' '====================================================='
printf ' Python Toolchain Setup - Unix\n'
printf ' pyenv + Python %s + Poetry\n' "$PYTHON_VERSION"
printf '%s\n\n' '====================================================='

# -------------------------------------------------------
# 0. Helpers / prerequisites
# -------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    fi
fi

install_linux_dependencies() {
    # Python installed by pyenv is compiled from source on Unix, so build
    # dependencies are needed. We install them only when a supported package
    # manager is available.
    if command -v apt-get >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with apt-get..."
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            build-essential curl git ca-certificates make gcc \
            libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
            libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev uuid-dev
    elif command -v dnf >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with dnf..."
        $SUDO dnf install -y \
            gcc gcc-c++ make patch curl git openssl-devel zlib-devel \
            bzip2 bzip2-devel readline-devel sqlite sqlite-devel tk-devel \
            libffi-devel xz-devel libuuid-devel
    elif command -v yum >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with yum..."
        $SUDO yum install -y \
            gcc gcc-c++ make patch curl git openssl-devel zlib-devel \
            bzip2 bzip2-devel readline-devel sqlite sqlite-devel tk-devel \
            libffi-devel xz-devel libuuid-devel
    elif command -v zypper >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with zypper..."
        $SUDO zypper --non-interactive install \
            gcc gcc-c++ make patch curl git libopenssl-devel zlib-devel \
            libbz2-devel readline-devel sqlite3-devel tk-devel libffi-devel xz-devel
    elif command -v pacman >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with pacman..."
        $SUDO pacman -Sy --needed --noconfirm \
            base-devel curl git openssl zlib bzip2 readline sqlite xz tk libffi
    elif command -v apk >/dev/null 2>&1; then
        [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ] || fail "sudo is required to install build dependencies."
        status "Installing/reusing Python build dependencies with apk..."
        $SUDO apk add --no-cache \
            build-base curl git openssl-dev zlib-dev bzip2-dev readline-dev \
            sqlite-dev xz-dev tk-dev libffi-dev linux-headers
    else
        warn "No supported Linux package manager detected."
        warn "Assuming Python build dependencies are already installed."
    fi
}

install_macos_dependencies() {
    if ! xcode-select -p >/dev/null 2>&1; then
        fail "Xcode Command Line Tools are required. Run 'xcode-select --install' once, finish it, then rerun this script."
    fi

    if command -v brew >/dev/null 2>&1; then
        status "Installing/reusing Python build libraries with Homebrew..."
        brew install openssl@3 readline sqlite3 xz zlib tcl-tk libffi || true
    else
        warn "Homebrew is not installed. Continuing with Xcode Command Line Tools only."
        warn "If Python compilation fails, install Homebrew and rerun this script."
    fi

    command -v curl >/dev/null 2>&1 || fail "curl is required."
    command -v git  >/dev/null 2>&1 || fail "git is required."
}

case "$(uname -s 2>/dev/null || printf unknown)" in
    Darwin)
        install_macos_dependencies
        ;;
    Linux)
        install_linux_dependencies
        ;;
    *)
        status "Generic Unix-like OS detected. Checking required commands..."
        command -v curl >/dev/null 2>&1 || fail "curl is required."
        command -v git  >/dev/null 2>&1 || fail "git is required."
        ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v git  >/dev/null 2>&1 || fail "git is required."

# -------------------------------------------------------
# 1. Install or reuse pyenv
# -------------------------------------------------------
if command -v pyenv >/dev/null 2>&1; then
    status "pyenv is already installed. Reusing it."
    PYENV_ROOT="$(pyenv root 2>/dev/null || printf '%s' "$DEFAULT_PYENV_ROOT")"
else
    PYENV_ROOT="$DEFAULT_PYENV_ROOT"
    if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
        status "Found pyenv at $PYENV_ROOT. Reusing it."
    else
        status "pyenv not found. Installing with the official pyenv installer..."
        curl -fsSL https://pyenv.run | bash
    fi
fi

export PYENV_ROOT
export PATH="$PYENV_ROOT/bin:$PATH"

[ -x "$PYENV_ROOT/bin/pyenv" ] || command -v pyenv >/dev/null 2>&1 || \
    fail "pyenv installation completed but the pyenv command cannot be found."

# Initialize pyenv for this running script. The generic form works in Bash.
eval "$(pyenv init -)"

status "pyenv version: $(pyenv --version)"

# -------------------------------------------------------
# 1a. Persist pyenv + Poetry PATH for future shells
# -------------------------------------------------------
remove_managed_block() {
    local file="$1" tmp
    [ -f "$file" ] || return 0
    tmp="${file}.python_toolchain_tmp.$$"
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip       { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

append_managed_block() {
    local file="$1"
    touch "$file"
    remove_managed_block "$file"
    cat >> "$file" <<EOF_PROFILE

$MARKER_BEGIN
export PYENV_ROOT="$PYENV_ROOT"
[ -d "\$PYENV_ROOT/bin" ] && export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"
export PATH="$POETRY_BIN_DIR:\$PATH"
$MARKER_END
EOF_PROFILE
}

# Bash commonly uses .bashrc for interactive shells and one of the profile
# files for login shells. Zsh uses .zshrc. We update only files relevant to
# shells present on the machine, and our own marked block is idempotent.
if command -v bash >/dev/null 2>&1; then
    append_managed_block "$HOME/.bashrc"
    if [ -f "$HOME/.bash_profile" ]; then
        append_managed_block "$HOME/.bash_profile"
    else
        append_managed_block "$HOME/.profile"
    fi
fi

if command -v zsh >/dev/null 2>&1 || [ "${SHELL:-}" = "/bin/zsh" ]; then
    append_managed_block "$HOME/.zshrc"
fi

# -------------------------------------------------------
# 2. Install or reuse Python 3.12.9
# -------------------------------------------------------
printf '\n'
status "Checking Python $PYTHON_VERSION in pyenv..."

if pyenv versions --bare 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$PYTHON_VERSION"; then
    status "Python $PYTHON_VERSION is already installed. Reusing it."
else
    status "Python $PYTHON_VERSION not found. Installing via pyenv..."
    # -s means skip if the version becomes available during a concurrent/retry run.
    # Unix pyenv builds non-interactively; there is no installer pause dialog.
    pyenv install -s "$PYTHON_VERSION"
fi

status "Setting pyenv global Python to $PYTHON_VERSION..."
pyenv global "$PYTHON_VERSION"
pyenv rehash

# Refresh shims after selecting the requested version.
eval "$(pyenv init -)"

ACTIVE_PYTHON="$(python --version 2>&1 | awk '{print $2}')"
status "Active Python: $ACTIVE_PYTHON"
[ "$ACTIVE_PYTHON" = "$PYTHON_VERSION" ] || \
    fail "Expected Python $PYTHON_VERSION, but active Python is $ACTIVE_PYTHON."

PYTHON_EXE="$(pyenv which python)"
[ -x "$PYTHON_EXE" ] || fail "Could not resolve the pyenv Python executable."

# -------------------------------------------------------
# 3. Install or reuse Poetry
# -------------------------------------------------------
printf '\n'
status "Checking Poetry..."
mkdir -p "$POETRY_BIN_DIR"
export PATH="$POETRY_BIN_DIR:$PATH"
hash -r 2>/dev/null || true

poetry_is_healthy() {
    command -v poetry >/dev/null 2>&1 && poetry --version >/dev/null 2>&1
}

if poetry_is_healthy; then
    status "Poetry is already installed and working. Reusing it."
else
    if command -v poetry >/dev/null 2>&1; then
        BROKEN_POETRY="$(command -v poetry)"
        warn "A Poetry command exists but is broken: $BROKEN_POETRY"
        case "$BROKEN_POETRY" in
            "$HOME"/*)
                status "Removing the broken user-level Poetry launcher..."
                rm -f "$BROKEN_POETRY"
                ;;
            *)
                warn "The broken Poetry launcher is outside your home directory; it will not be deleted."
                ;;
        esac
    fi

    # Remove stale user-level Poetry environments that can leave a launcher
    # pointing at a Python executable that no longer exists.
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/pypoetry" 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/pypoetry" 2>/dev/null || true
    rm -f "$POETRY_BIN_DIR/poetry" 2>/dev/null || true

    status "Poetry not found/healthy. Installing with the official installer..."
    POETRY_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/install-poetry.XXXXXX.py")"
    trap 'rm -f "${POETRY_INSTALLER:-}"' EXIT
    curl -fsSL https://install.python-poetry.org -o "$POETRY_INSTALLER"
    "$PYTHON_EXE" "$POETRY_INSTALLER" --yes --force
    rm -f "$POETRY_INSTALLER"
    trap - EXIT
fi

hash -r 2>/dev/null || true

if ! command -v poetry >/dev/null 2>&1; then
    fail "Poetry was installed but the poetry command cannot be found. Expected: $POETRY_BIN_DIR/poetry"
fi

if ! poetry --version >/dev/null 2>&1; then
    fail "Poetry command exists but failed to run."
fi

# -------------------------------------------------------
# 4. Final verification
# -------------------------------------------------------
printf '\n%s\n' '====================================================='
printf '%s\n' ' SETUP COMPLETED SUCCESSFULLY'
printf '%s\n\n' '====================================================='

printf '[VERIFY] pyenv:\n'
pyenv --version
printf '\n[VERIFY] Python:\n'
python --version
printf '\n[VERIFY] Python executable:\n'
command -v python
printf '\n[VERIFY] Poetry:\n'
poetry --version
printf '\n[VERIFY] Poetry executable:\n'
command -v poetry
printf '\nPython %s, pyenv, and Poetry are ready.\n' "$PYTHON_VERSION"
printf 'Open a NEW terminal/IDE to verify the persisted shell configuration.\n'
