#!/usr/bin/env bash

set -euo pipefail

INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${HOME}/.local"

install_usage() {
    cat <<'EOF'
Install the Reproera command into a user-owned prefix.

Usage:
  ./install.sh [--prefix PATH]

The default prefix is $HOME/.local. The installer does not use sudo or edit
shell startup files.
EOF
}

install_die() {
    printf '[reproera installer] error: %s\n' "$*" >&2
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --prefix)
            [[ "$#" -ge 2 && -n "$2" ]] || install_die "--prefix requires a path"
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            install_usage
            exit 0
            ;;
        *)
            install_die "unknown option: $1"
            ;;
    esac
done

[[ -f "$INSTALL_SCRIPT_DIR/bin/reproera" ]] \
    || install_die "run this script from a complete Reproera source checkout"
for library in common.sh doctor.sh install.sh registry.sh; do
    [[ -f "$INSTALL_SCRIPT_DIR/lib/$library" ]] \
        || install_die "missing runtime file: lib/$library"
done
command -v install >/dev/null 2>&1 || install_die "the install command is required"

mkdir -p "$INSTALL_PREFIX"
INSTALL_PREFIX="$(cd "$INSTALL_PREFIX" && pwd -P)"
runtime_root="$INSTALL_PREFIX/libexec/reproera"
launcher="$INSTALL_PREFIX/bin/reproera"
launcher_target="../libexec/reproera/bin/reproera"

if [[ -e "$launcher" && ! -L "$launcher" ]]; then
    install_die "refusing to replace existing file: $launcher"
fi
if [[ -L "$launcher" && "$(readlink "$launcher")" != "$launcher_target" ]]; then
    install_die "refusing to replace unrelated symbolic link: $launcher"
fi

install -d "$runtime_root/bin" "$runtime_root/lib" "$INSTALL_PREFIX/bin"
install -m 0755 "$INSTALL_SCRIPT_DIR/bin/reproera" "$runtime_root/bin/reproera"
for library in common.sh doctor.sh install.sh registry.sh; do
    install -m 0644 "$INSTALL_SCRIPT_DIR/lib/$library" "$runtime_root/lib/$library"
done

if [[ ! -L "$launcher" ]]; then
    ln -s "$launcher_target" "$launcher"
fi

printf '[reproera installer] installed %s\n' "$launcher"
case ":${PATH}:" in
    *":$INSTALL_PREFIX/bin:"*) ;;
    *)
        printf '[reproera installer] add %s/bin to PATH, then run: reproera doctor\n' \
            "$INSTALL_PREFIX"
        ;;
esac
