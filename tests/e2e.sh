#!/usr/bin/env bash

set -euo pipefail

E2E_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E2E_ROOT="$(cd "${E2E_SCRIPT_DIR}/.." && pwd)"

if [[ "${EUID}" -eq 0 ]]; then
    printf 'error: the end-to-end build must run as an unprivileged user\n' >&2
    exit 1
fi

if [[ -n "${REPROERA_E2E_ROOT:-}" ]]; then
    E2E_WORK_ROOT="${REPROERA_E2E_ROOT}"
    mkdir -p "$E2E_WORK_ROOT"
else
    E2E_WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/reproera-e2e.XXXXXXXX")"
fi

export REPROERA_CACHE_DIR="${E2E_WORK_ROOT}/cache"
export SHELL="/bin/bash"
E2E_JOBS="${REPROERA_E2E_JOBS:-2}"
E2E_PROJECT_ROOT="${E2E_WORK_ROOT}/project"
E2E_PREFIX="${E2E_PROJECT_ROOT}/.reproera/prefix"
E2E_CHECKOUT="${E2E_PROJECT_ROOT}/Reproera"
mkdir -p "$E2E_CHECKOUT/bin" "$E2E_CHECKOUT/lib"
cp "$E2E_ROOT/install.sh" "$E2E_CHECKOUT/install.sh"
cp "$E2E_ROOT/bin/reproera" "$E2E_CHECKOUT/bin/reproera"
cp "$E2E_ROOT"/lib/*.sh "$E2E_CHECKOUT/lib/"

bash "$E2E_CHECKOUT/install.sh" --project
rm -rf "$E2E_CHECKOUT"
source "$E2E_PROJECT_ROOT/.reproera/activate"
REPROERA="$(command -v reproera)"
cd "$E2E_PROJECT_ROOT"

printf 'Reproera end-to-end source build\n'
printf '  user:      %s (uid %s)\n' "$(id -un)" "$(id -u)"
printf '  compiler:  %s\n' "${CC:-cc}"
printf '  workspace: %s\n' "$E2E_WORK_ROOT"
printf '  project:   %s\n' "$E2E_PROJECT_ROOT"
printf '  cli:       %s\n' "$REPROERA"
printf '  prefix:    %s\n' "$E2E_PREFIX"

"$REPROERA" init tmux python
"$REPROERA" doctor
"$REPROERA" install --jobs "$E2E_JOBS"

# The project activation must make installed programs discoverable and provide
# runtime paths for libraries built inside the private prefix.
source "$E2E_PROJECT_ROOT/.reproera/activate"
hash -r

python_bin="$(command -v python3.11)"
tmux_bin="$(command -v tmux)"
perl_bin="$(command -v perl)"
[[ "$python_bin" == "$E2E_PREFIX/bin/python3.11" ]]
[[ "$tmux_bin" == "$E2E_PREFIX/bin/tmux" ]]
[[ "$perl_bin" == "$E2E_PREFIX/bin/perl" ]]
"$perl_bin" -MIPC::Cmd -MTime::Piece -e 1
"$REPROERA" verify

REPROERA_EXPECTED_PREFIX="$E2E_PREFIX" "$python_bin" - <<'PY'
import _ssl
import bz2
import ctypes
import curses
import hashlib
import lzma
import os
import readline
import sqlite3
import ssl
import sys
import zlib

prefix = os.environ["REPROERA_EXPECTED_PREFIX"]
assert sys.prefix == prefix, (sys.prefix, prefix)
assert ssl.OPENSSL_VERSION.startswith("OpenSSL 3.5.8"), ssl.OPENSSL_VERSION
assert zlib.ZLIB_VERSION == "1.3.1", zlib.ZLIB_VERSION
assert sqlite3.sqlite_version == "3.53.4", sqlite3.sqlite_version
assert bz2.decompress(bz2.compress(b"reproera")) == b"reproera"
assert lzma.decompress(lzma.compress(b"reproera")) == b"reproera"
assert ctypes.sizeof(ctypes.c_void_p) > 0
assert curses.version
assert hashlib.sha256(b"reproera").hexdigest() == (
    "4b71150a4795e72e19df77acd5d34f0d949ae5df9aafc7e5b55243eb502fc3d1"
)
print("Python:", sys.version.split()[0])
print("OpenSSL:", ssl.OPENSSL_VERSION)
print("zlib:", zlib.ZLIB_VERSION)
print("SQLite:", sqlite3.sqlite_version)
print("_ssl:", _ssl.__file__)
PY

assert_module_link() {
    local module="$1" library_pattern="$2" module_file module_links
    module_file="$($python_bin -c "import $module; print($module.__file__)")"
    module_links="$(ldd "$module_file")"
    printf '%s\n' "$module_links" | grep -E "$library_pattern" | grep -F "$E2E_PREFIX/" >/dev/null
}

assert_module_link _ssl 'lib(ssl|crypto)'
assert_module_link _ctypes 'libffi'
assert_module_link _curses 'lib(ncurses|tinfo)'
assert_module_link _lzma 'liblzma'
assert_module_link _sqlite3 'libsqlite3'
assert_module_link readline 'libreadline'

# CPython links its bz2 extension to Reproera's PIC static archive, so a
# successful build and round-trip above prove it did not use a system -devel
# package (none is installed in the CentOS 7 image).

tmux_links="$(ldd "$tmux_bin")"
printf '%s\n' "$tmux_links" | grep -E 'libevent' | grep -F "$E2E_PREFIX/" >/dev/null
printf '%s\n' "$tmux_links" | grep -E 'lib(ncurses|tinfo)' | grep -F "$E2E_PREFIX/" >/dev/null

"$tmux_bin" -V | grep -F 'tmux 3.6b' >/dev/null
"$tmux_bin" -L reproera-e2e -f /dev/null new-session -d -s smoke 'sleep 30'
"$tmux_bin" -L reproera-e2e has-session -t smoke
"$tmux_bin" -L reproera-e2e kill-server

# A second installation must use the prefix-scoped markers and perform no
# downloads or builds.
second_install="$($REPROERA install --jobs "$E2E_JOBS" 2>&1)"
printf '%s\n' "$second_install" | grep -F 'is already installed' >/dev/null
if printf '%s\n' "$second_install" | grep -E '\b(downloading|building)\b' >/dev/null; then
    printf 'error: the second installation unexpectedly rebuilt a package\n' >&2
    exit 1
fi

if find "$E2E_PROJECT_ROOT/.reproera" ! -user "$(id -u)" -print -quit | grep -q .; then
    printf 'error: the installation prefix contains files owned by another user\n' >&2
    exit 1
fi

printf 'End-to-end source build passed.\n'
