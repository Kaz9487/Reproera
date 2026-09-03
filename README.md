# Reproera

[![CI](https://github.com/Kaz9487/Reproera/actions/workflows/ci.yml/badge.svg)](https://github.com/Kaz9487/Reproera/actions/workflows/ci.yml)
[![End-to-end source build](https://github.com/Kaz9487/Reproera/actions/workflows/e2e.yml/badge.svg)](https://github.com/Kaz9487/Reproera/actions/workflows/e2e.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Reproera builds selected developer tools into a user-owned Linux prefix without
`sudo`. It targets constrained university and laboratory servers where the base
OS, compiler, and system packages may be old.

The name combines **reproducible** with **era**: reproducible development
environments across different eras of Linux systems.

> **Status:** `0.1.0-alpha.1`. Review the limitations before using it on an
> important machine.

## Why Reproera?

On shared servers, users often cannot upgrade Python, tmux, OpenSSL, or other
build dependencies. Copy-pasted installation commands tend to omit checksums,
mix files across prefixes, and break differently under Bash and tcsh. Reproera
turns that process into an inspectable build plan with pinned sources.

## Current capabilities

- Diagnose the OS, shell, compiler, build commands, downloader, checksum tool,
  and prefix permissions.
- Detect GCC and Clang, including old GCC versions.
- Resolve and display dependency-aware build plans.
- Build pinned Python and tmux stacks, including their native dependencies.
- Emit environment setup for Bash, Zsh, and tcsh.
- Refuse unknown versions and fail on checksum mismatches.
- Test compiler detection against GCC 4.8.5 through 13.3.0 fixtures.

GCC installation is **not implemented** in this alpha. Reproera diagnoses the
host compiler; a complete GCC bootstrap recipe will require pinned GMP, MPFR,
MPC, and ISL dependencies.

## Quick start

From the root of the project that needs the environment, clone Reproera as a
temporary child directory and install its CLI locally:

```bash
cd /path/to/my-project
git clone --depth 1 https://github.com/Kaz9487/Reproera.git
./Reproera/install.sh --project

# Bash or Zsh (use the activation command printed by the installer):
source .reproera/activate

reproera doctor
reproera init python@3.11.16 tmux@3.6b
reproera plan
reproera install --jobs 2
```

For tcsh or csh, replace the activation line above with:

```tcsh
source .reproera/activate.tcsh
```

`--project` treats the Reproera checkout's parent as the project root. It copies
the CLI into `.reproera`, creates `.reproera/activate` for Bash and Zsh, and
creates `.reproera/activate.tcsh` for tcsh and csh. The source checkout can then
be removed after installation succeeds, but the installer never removes it
automatically. Activation binds `REPROERA_PREFIX` and `REPROERA_STATE_DIR` to
that project, so commands cannot fall back to `~/.local` before
`reproera.toml` exists. Re-enter the project later by sourcing the appropriate
activation file again.

For backward compatibility, `./install.sh` still installs the CLI into
`~/.local`; `./install.sh --prefix PATH` selects another explicit user-owned
prefix. Project mode does not modify `~/.local` or shell startup files. Source
archives remain shared in `~/.cache/reproera` unless `REPROERA_CACHE_DIR` is
overridden.

## Project environments

`reproera init` creates a pinned `reproera.toml` and a private `.reproera/`
runtime directory. With no package arguments it selects the default Python;
packages can instead be specified explicitly:

```bash
reproera init python@3.11.9 tmux@3.3a
```

From the project root or any child directory, `doctor`, `plan`, `install`, and
`env` automatically use `.reproera/prefix` and `.reproera/state`. Source
archives remain in the shared `~/.cache/reproera` cache. This keeps compiled
environments isolated without downloading the same archives for every project.

For a project-local tcsh environment:

```tcsh
source .reproera/activate.tcsh
reproera doctor
```

For an explicitly global installation, `reproera shell-init tcsh --apply`
remains available and creates `~/.cshrc.reproera.bak` before changing an
existing file. Without `--apply`, it only prints the lines it would add.

## Commands

```text
reproera doctor [--json]
reproera list
reproera init [PACKAGE[@VERSION] ...]
reproera plan [PACKAGE[@VERSION]]
reproera install [PACKAGE[@VERSION]] [--prefix PATH] [--jobs N] [--dry-run]
reproera env [bash|zsh|tcsh]
reproera shell-init [bash|zsh|tcsh] [--apply]
```

## Supported recipes

| Package | Pinned version | Notes |
| --- | ---: | --- |
| zlib | 1.3.1 | Python dependency |
| bzip2 | 1.0.8 | Enables Python `bz2` |
| xz | 5.8.3 | Enables Python `lzma` |
| libffi | 3.8.0 | Enables Python `ctypes` |
| SQLite | 3.53.4 | Enables Python `sqlite3` |
| OpenSSL | 3.5.8 LTS | Python dependency |
| ncurses | 6.5 | Enables Python `curses`; tmux dependency |
| readline | 8.3 | Enables Python `readline` |
| libevent | 2.1.13-stable | Built without OpenSSL |
| Python | 3.11.16 | Uses `altinstall`; 3.11.9 also available explicitly |
| tmux | 3.6b | Links to the user prefix; 3.3a also available explicitly |
| GCC | 11.5.0 target | Diagnostics only |

## Testing

The local test suite performs no network access and does not install packages:

```bash
bash tests/test.sh
```

GitHub Actions adds CentOS 7, Rocky Linux 8, Ubuntu 24.04, and ShellCheck jobs.
See [docs/design.md](docs/design.md) for the distinction between simulated GCC
versions and real container coverage.

The networked end-to-end test initializes a temporary project and performs
clean source builds as an unprivileged CentOS 7 user. It validates automatic
project discovery, Python native modules and dynamic library origins, starts a
real tmux server, and checks that repeated installations are idempotent:

```bash
bash tests/e2e.sh
```

It runs weekly, whenever installer or end-to-end test code changes, and can
also be started manually with the **End-to-end source build** workflow. Expect
it to take substantially longer than the offline test suite.

## Known limitations

- The scheduled CentOS 7 end-to-end source build is intentionally separate
  from the fast pull-request test suite.
- Tkinter and UUID integration remain dependent on libraries supplied by the
  host and may be omitted from Python.
- Build resume, uninstall, binary caches, ARM64, proxies, and offline source
  bundles are not implemented.
- The installation marker records recipe completion but is not yet a full
  content manifest.

Please do not report the alpha as production-ready until the real container
build matrix is green.

## Security

Reproera never invokes `sudo` and does not pipe remote content into a shell.
Source archives are checked against pinned SHA-256 digests before extraction,
and unsafe absolute or parent-traversing archive paths are rejected.
Review recipes before use, especially on shared systems.

Please follow [SECURITY.md](SECURITY.md) when reporting a vulnerability. Never
include credentials, private hostnames, or private filesystem paths in a public
issue.

## License

MIT. See [LICENSE](LICENSE).
