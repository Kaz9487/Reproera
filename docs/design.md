# Reproera design notes

## Scope

Reproera bootstraps selected developer tools into a user-owned installation
prefix. It does not modify system packages, invoke `sudo`, or replace a general
package manager.

## Compatibility baseline

- Bash 4.2 or newer
- Linux x86-64 initially
- A working C compiler, `make`, `tar`, `awk`, `sed`, and `sort`
- `curl` or `wget`
- `sha256sum` or `shasum`
- Perl with `IPC::Cmd` and `Time::Piece` when building OpenSSL

The initial compiler test matrix models GCC 4.8.5, 7.5.0, 11.5.0, and 13.3.0.
The wrappers exercise detection and version-dependent behavior; they do not
claim ABI-level equivalence to each compiler. Container CI provides the real
CentOS 7/GCC 4.8 environment when GitHub Actions is enabled.

The separate end-to-end workflow runs the installer as a non-root CentOS 7
user. It compiles every declared Python and tmux dependency, checks runtime
linkage back to the private prefix, exercises Python's SSL and zlib modules,
starts a tmux server, and repeats both installations to verify marker-based
idempotency. It is scheduled weekly rather than on every pull request because
it downloads and rebuilds the complete graph.

## Trust model

Every supported source archive has a pinned SHA-256 digest. A checksum mismatch
is fatal. Downloads use HTTPS and are first written to a `.part` file. Reproera
does not execute remote installer scripts. Archive member names are checked for
absolute paths and parent-directory traversal before extraction.

## Build graph

```text
python -> zlib, openssl 3.5 LTS
tmux   -> ncurses, libevent
```

The dependency graph is deliberately small for the alpha. Python 3.11.16 is
the maintained source-only security release used by default; 3.11.9 remains an
explicit compatibility recipe. Python extension
modules that require additional libraries may be absent. GCC source bootstrap,
resume support, signed release verification, and a lockfile are future work.

## Filesystem layout

```text
~/.local/                 installation prefix
~/.cache/reproera/        downloaded archives
~/.local/share/reproera/  build trees and installation markers
```

All locations are overrideable with `REPROERA_PREFIX`, `REPROERA_CACHE_DIR`,
and `REPROERA_STATE_DIR`.
