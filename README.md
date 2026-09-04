# Reproera

[![CI](https://github.com/Kaz9487/Reproera/actions/workflows/ci.yml/badge.svg)](https://github.com/Kaz9487/Reproera/actions/workflows/ci.yml)
[![End-to-end source build](https://github.com/Kaz9487/Reproera/actions/workflows/e2e.yml/badge.svg)](https://github.com/Kaz9487/Reproera/actions/workflows/e2e.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Rootless, reproducible developer environments for old and restricted Linux
systems.

Reproera builds pinned Python and tmux toolchains inside each project without
`sudo`, changing system packages, or mixing files with other projects. It is
designed for shared university and laboratory servers such as CentOS 7 hosts
with GCC 4.8.5.

> **Status:** `0.1.0-alpha.1`. Reproera currently targets Linux x86-64.

## Quick start

Run these commands from the project that needs the environment:

```bash
cd /path/to/my-project
git clone --depth 1 https://github.com/Kaz9487/Reproera.git
./Reproera/install.sh --project

# Bash or Zsh
source .reproera/activate

reproera doctor
reproera init python@3.11.16 tmux@3.6b
reproera plan
reproera install --jobs 2
reproera verify
```

For tcsh or csh, use this activation command instead:

```tcsh
source .reproera/activate.tcsh
```

The installer copies the CLI into `.reproera`, so the cloned `Reproera/`
directory may be removed afterward. Reproera never removes it automatically.
Source the activation file again when opening a new shell.

## What it installs

| Tool | Default version |
| --- | ---: |
| Python | 3.11.16 |
| tmux | 3.6b |

Their pinned native dependencies are built into the same project prefix,
including zlib, bzip2, xz, libffi, SQLite, Perl, OpenSSL, ncurses, readline,
and libevent. Python 3.11.9 and tmux 3.3a are also available when explicitly
requested.

GCC installation is not implemented. Reproera detects and validates the host
compiler, including GCC 4.8.5, but uses it to build the selected environment.

## Commands

| Command | Purpose |
| --- | --- |
| `reproera doctor` | Check the host and project prefix |
| `reproera init ...` | Create a pinned `reproera.toml` |
| `reproera plan` | Show the dependency build order |
| `reproera install` | Download, verify, build, and install |
| `reproera verify` | Verify packages and the active shell environment |
| `reproera list` | Show supported recipes and defaults |
| `reproera env SHELL` | Print shell environment code |
| `reproera shell-init SHELL [--apply]` | Generate or apply persistent setup |

`reproera env` only prints shell code; it cannot modify its parent shell.
Project users should normally source `.reproera/activate` or
`.reproera/activate.tcsh`.

## Project isolation

- `reproera.toml` records the versions requested by the project.
- `.reproera/prefix` contains that project's compiled tools and libraries.
- `.reproera/state` contains project-scoped build state and install markers.
- `~/.cache/reproera` shares downloaded source archives across projects.

The original global modes remain available through `./install.sh` and
`./install.sh --prefix PATH`, but `--project` is recommended.

## Verification and support

The complete Python and tmux stack is source-built as an unprivileged user in
a CentOS 7 / GCC 4.8.5 end-to-end workflow. Fast CI also covers Rocky Linux 8,
Ubuntu 24.04, compiler detection, shell behavior, and archive safety.

Current limitations include no build resume, uninstall, binary cache, ARM64,
proxy, or offline source-bundle support. Tkinter and UUID support may depend on
host libraries.

See [Design](docs/design.md), [Changelog](CHANGELOG.md),
[Contributing](CONTRIBUTING.md), and [Security](SECURITY.md) for details.

## License

[MIT](LICENSE)
