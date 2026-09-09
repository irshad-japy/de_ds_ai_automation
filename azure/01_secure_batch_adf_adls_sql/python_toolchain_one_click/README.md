# Python Toolchain One-Click

One-click scripts to install, reuse, verify, and uninstall **pyenv**, **Python 3.12.9**, and **Poetry** on Windows and Unix-based systems.

## Included scripts

```text
windows/
├── install_python_toolchain.bat
└── uninstall_python_toolchain.bat

unix/
├── install_python_toolchain.sh
└── uninstall_python_toolchain.sh
```

The install scripts reuse an existing working installation when possible. Poetry installation and verification are handled directly by the main installer scripts; no separate Poetry installer or repair script is required.

---

## Windows / Windows Amazon WorkSpaces

### Install

Run from Command Prompt:

```bat
windows\install_python_toolchain.bat
```

The default Python version is **3.12.9**. You can also explicitly pass the version:

```bat
windows\install_python_toolchain.bat 3.12.9
```

The installer will:

- Install or reuse `pyenv-win`.
- Install or reuse Python `3.12.9`.
- Set Python `3.12.9` as the active global pyenv version.
- Install or reuse Poetry.
- Add the required pyenv and Poetry directories to the Windows User `PATH`.
- Verify pyenv, Python, and Poetry before reporting success.

### Verify after installation

After installation, close the current Command Prompt and open a **new Command Prompt**. Then run:

```bat
pyenv --version
pyenv version
python --version
where python
poetry --version
where poetry
```

Expected Python version:

```text
Python 3.12.9
```

`where python` should normally point to pyenv shims, for example:

```text
C:\Users\<username>\.pyenv\pyenv-win\shims\python
C:\Users\<username>\.pyenv\pyenv-win\shims\python.bat
```

`where poetry` should normally point to:

```text
C:\Users\<username>\AppData\Roaming\Python\Scripts\poetry.exe
```

### Poetry behavior on Windows

Poetry is installed using the official installer:

```text
https://install.python-poetry.org
```

The installer adds the Poetry command directory to the Windows User `PATH`:

```text
%APPDATA%\Python\Scripts
```

If Poetry is already installed and working, it is reused. If a stale or broken Poetry launcher is detected, the installer repairs/reinstalls Poetry and only reports success after `poetry --version` works.

### Uninstall

Run:

```bat
windows\uninstall_python_toolchain.bat
```

The uninstaller removes the toolchain managed by these scripts while preserving unrelated/system Python installations.

After uninstalling, close the current terminal and open a new one so the updated environment variables and `PATH` are reloaded.

---

## macOS / Linux / Unix / WSL

### Make the scripts executable

Run once:

```bash
chmod +x unix/install_python_toolchain.sh
chmod +x unix/uninstall_python_toolchain.sh
```

Or:

```bash
chmod +x unix/install_python_toolchain.sh unix/uninstall_python_toolchain.sh
```

### Install

Run:

```bash
./unix/install_python_toolchain.sh
```

The installer will:

- Install or reuse pyenv.
- Install required Python build dependencies when supported by the operating system/package manager.
- Install or reuse Python `3.12.9`.
- Set Python `3.12.9` as the active global pyenv version.
- Install or reuse Poetry.
- Configure the required shell environment and `PATH` entries.
- Verify pyenv, Python, and Poetry before reporting success.

### Verify after installation

After installation, close the current terminal and open a **new terminal**. Then run:

```bash
pyenv --version
pyenv version
python --version
which python
poetry --version
which poetry
```

Expected Python version:

```text
Python 3.12.9
```

`which python` should normally point to pyenv shims, for example:

```text
/home/<username>/.pyenv/shims/python
```

`which poetry` will normally point to the Poetry executable available through your configured user `PATH`.

> **Note:** Windows uses `where`, while macOS/Linux/Unix/WSL normally use `which`.

### Uninstall

Run:

```bash
./unix/uninstall_python_toolchain.sh
```

The uninstaller removes the pyenv/Python/Poetry installation managed by these scripts and cleans the shell configuration added for this toolchain. It does not intentionally remove the operating system's own Python installation.

After uninstalling, close the current terminal and open a new one.

---

## Quick verification reference

### Windows

```bat
pyenv --version
pyenv version
python --version
where python
poetry --version
where poetry
```

### Unix / Linux / macOS / WSL

```bash
pyenv --version
pyenv version
python --version
which python
poetry --version
which poetry
```
