# Reproera

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
- Build pinned zlib, OpenSSL LTS, ncurses, libevent, Python, and tmux sources.
- Emit environment setup for Bash, Zsh, and tcsh.
- Refuse unknown versions and fail on checksum mismatches.
- Test compiler detection against GCC 4.8.5 through 13.3.0 fixtures.

GCC installation is **not implemented** in this alpha. Reproera diagnoses the
host compiler; a complete GCC bootstrap recipe will require pinned GMP, MPFR,
MPC, and ISL dependencies.

## Quick start

```bash
git clone https://github.com/Kaz9487/Reproera.git reproera
cd reproera
chmod +x bin/reproera tests/test.sh
export PATH="$PWD/bin:$PATH"

reproera doctor
reproera plan python
reproera install python --prefix "$HOME/.local"
eval "$(reproera env bash)"
```

For tcsh:

```tcsh
reproera shell-init tcsh
reproera shell-init tcsh --apply
source ~/.cshrc
```

`--apply` creates `~/.cshrc.reproera.bak` before changing an existing file.
Without `--apply`, the command only prints the lines it would add.

## Commands

```text
reproera doctor [--json]
reproera list
reproera plan PACKAGE[@VERSION]
reproera install PACKAGE[@VERSION] [--prefix PATH] [--jobs N] [--dry-run]
reproera env [bash|zsh|tcsh]
reproera shell-init [bash|zsh|tcsh] [--apply]
```

## Supported recipes

| Package | Pinned version | Notes |
| --- | ---: | --- |
| zlib | 1.3.1 | Python dependency |
| OpenSSL | 3.5.8 LTS | Python dependency |
| ncurses | 6.5 | tmux dependency |
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

## Known limitations

- The source-build recipes have not yet completed an end-to-end CentOS 7 build
  in this alpha.
- Python may omit optional modules whose development libraries are unavailable,
  such as `_bz2`, `_lzma`, `_sqlite3`, `_ctypes`, or `readline`.
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

## License

MIT. See [LICENSE](LICENSE).
