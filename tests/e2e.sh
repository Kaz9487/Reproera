#!/usr/bin/env bash

set -euo pipefail

E2E_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
E2E_ROOT="$(cd "${E2E_SCRIPT_DIR}/.." && pwd)"
REPROERA="${E2E_ROOT}/bin/reproera"

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

export REPROERA_PREFIX="${E2E_WORK_ROOT}/prefix"
export REPROERA_STATE_DIR="${E2E_WORK_ROOT}/state"
export REPROERA_CACHE_DIR="${E2E_WORK_ROOT}/cache"
export SHELL="/bin/bash"
E2E_JOBS="${REPROERA_E2E_JOBS:-2}"

printf 'Reproera end-to-end source build\n'
printf '  user:      %s (uid %s)\n' "$(id -un)" "$(id -u)"
printf '  compiler:  %s\n' "${CC:-cc}"
printf '  workspace: %s\n' "$E2E_WORK_ROOT"
printf '  prefix:    %s\n' "$REPROERA_PREFIX"

"$REPROERA" doctor
"$REPROERA" install python --jobs "$E2E_JOBS"
"$REPROERA" install tmux --jobs "$E2E_JOBS"

# The generated environment must make the installed programs discoverable and
# provide runtime paths for libraries built inside the private prefix.
eval "$("$REPROERA" env bash)"
hash -r

python_bin="$(command -v python3.11)"
tmux_bin="$(command -v tmux)"
[[ "$python_bin" == "$REPROERA_PREFIX/bin/python3.11" ]]
[[ "$tmux_bin" == "$REPROERA_PREFIX/bin/tmux" ]]

REPROERA_EXPECTED_PREFIX="$REPROERA_PREFIX" "$python_bin" - <<'PY'
import _ssl
import hashlib
import os
import ssl
import sys
import zlib

prefix = os.environ["REPROERA_EXPECTED_PREFIX"]
assert sys.prefix == prefix, (sys.prefix, prefix)
assert ssl.OPENSSL_VERSION.startswith("OpenSSL 3.5.8"), ssl.OPENSSL_VERSION
assert zlib.ZLIB_VERSION == "1.3.1", zlib.ZLIB_VERSION
assert hashlib.sha256(b"reproera").hexdigest() == (
    "4b71150a4795e72e19df77acd5d34f0d949ae5df9aafc7e5b55243eb502fc3d1"
)
print("Python:", sys.version.split()[0])
print("OpenSSL:", ssl.OPENSSL_VERSION)
print("zlib:", zlib.ZLIB_VERSION)
print("_ssl:", _ssl.__file__)
PY

ssl_module="$($python_bin -c 'import _ssl; print(_ssl.__file__)')"
ssl_links="$(ldd "$ssl_module")"
printf '%s\n' "$ssl_links" | grep -E 'lib(ssl|crypto)' >/dev/null
printf '%s\n' "$ssl_links" | grep -F "$REPROERA_PREFIX/" >/dev/null

tmux_links="$(ldd "$tmux_bin")"
printf '%s\n' "$tmux_links" | grep -E 'libevent' | grep -F "$REPROERA_PREFIX/" >/dev/null
printf '%s\n' "$tmux_links" | grep -E 'lib(ncurses|tinfo)' | grep -F "$REPROERA_PREFIX/" >/dev/null

"$tmux_bin" -V | grep -F 'tmux 3.6b' >/dev/null
"$tmux_bin" -L reproera-e2e -f /dev/null new-session -d -s smoke 'sleep 30'
"$tmux_bin" -L reproera-e2e has-session -t smoke
"$tmux_bin" -L reproera-e2e kill-server

# A second installation must use the prefix-scoped markers and perform no
# downloads or builds.
second_python="$($REPROERA install python --jobs "$E2E_JOBS" 2>&1)"
second_tmux="$($REPROERA install tmux --jobs "$E2E_JOBS" 2>&1)"
printf '%s\n%s\n' "$second_python" "$second_tmux" | grep -F 'is already installed' >/dev/null
if printf '%s\n%s\n' "$second_python" "$second_tmux" | grep -E '\b(downloading|building)\b' >/dev/null; then
    printf 'error: the second installation unexpectedly rebuilt a package\n' >&2
    exit 1
fi

if find "$REPROERA_PREFIX" ! -user "$(id -u)" -print -quit | grep -q .; then
    printf 'error: the installation prefix contains files owned by another user\n' >&2
    exit 1
fi

printf 'End-to-end source build passed.\n'
