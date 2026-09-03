# Changelog

## 0.1.0-alpha.1 - 2026-09-03

- Added a Bash 4.2-compatible command-line interface.
- Added text and JSON environment diagnostics.
- Added dependency-aware plans and pinned source recipes for zlib, OpenSSL,
  bzip2, xz, libffi, SQLite, ncurses, readline, libevent, Python, and tmux.
- Added a rootless self-installer and automatically discovered per-project
  environments driven by `reproera.toml`.
- Added Bash, Zsh, and native tcsh environment initialization.
- Added checksum enforcement, archive path validation, per-prefix installation
  markers, and post-install smoke checks.
- Added offline tests for GCC 4.8.5, 7.5.0, 11.5.0, and 13.3.0 detection.
- Added CI definitions for Ubuntu 24.04, Rocky Linux 8, CentOS 7, and ShellCheck.
- Added a weekly and manually dispatchable CentOS 7 end-to-end source build
  that runs as an unprivileged user and validates runtime linkage and
  idempotency.

GCC source bootstrap remains intentionally out of scope for this release.
