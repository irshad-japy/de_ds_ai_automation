#!/bin/bash

# Force script to terminate instantly if any command produces an execution fault
set -e

echo "==================================================="
echo " POC-08 Poetry bootstrap"
echo "==================================================="

# Inject pyenv and local system binary paths temporarily 
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$HOME/.local/bin:$PATH"

# 1. Force verify Python 3.12 availability
echo "[STATUS] Checking Python 3.12 version..."
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python 3 target executable context not found."
    exit 1
fi
python3 --version

# 2. Force verify Poetry availability
echo "[STATUS] Checking Poetry version..."
if ! command -v poetry &> /dev/null; then
    echo "[ERROR] Poetry command tool is not accessible."
    exit 1
fi
poetry --version

# 3. Configure Poetry to create virtual environments inside the project folder (.venv)
echo "[STATUS] Setting local virtual environment preferences..."
poetry config virtualenvs.in-project true

# 4. Direct Poetry to use Python 3.12
echo "[STATUS] Binding poetry environment to Python 3.12..."
poetry env use 3.12

# 5. Execute dependency installation
echo "[STATUS] Installing application package dependencies..."
poetry install

# 6. Verify profile configuration
echo "[STATUS] Triggering verify_config verification run..."
poetry run python -m scripts.verify_config --profile local

# 7. Execute testing engine suite
echo "[STATUS] Running unit testing framework infrastructure..."
poetry run pytest

echo "==================================================="
echo " Bootstrap completed."
echo "==================================================="
