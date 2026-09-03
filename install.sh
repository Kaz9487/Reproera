#!/usr/bin/env bash

set -euo pipefail

INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${HOME}/.local"
INSTALL_PROJECT_MODE=0
INSTALL_PREFIX_EXPLICIT=0
INSTALL_PROJECT_ROOT=""

install_usage() {
    cat <<'EOF'
Install the Reproera command into a user-owned prefix.

Usage:
  ./install.sh --project
  ./install.sh [--prefix PATH]

Options:
  --project      Install into .reproera in the source checkout's parent
                 directory and create project activation scripts.
  --prefix PATH  Install into an explicit user-owned prefix.

Without either option, the prefix defaults to $HOME/.local for backward
compatibility. The installer does not use sudo or edit shell startup files.
EOF
}

install_die() {
    printf '[reproera installer] error: %s\n' "$*" >&2
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --project)
            INSTALL_PROJECT_MODE=1
            shift
            ;;
        --prefix)
            [[ "$#" -ge 2 && -n "$2" ]] || install_die "--prefix requires a path"
            INSTALL_PREFIX="$2"
            INSTALL_PREFIX_EXPLICIT=1
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

if [[ "$INSTALL_PROJECT_MODE" -eq 1 && "$INSTALL_PREFIX_EXPLICIT" -eq 1 ]]; then
    install_die "--project and --prefix cannot be used together"
fi

if [[ "$INSTALL_PROJECT_MODE" -eq 1 ]]; then
    INSTALL_PROJECT_ROOT="$(dirname "$INSTALL_SCRIPT_DIR")"
    INSTALL_PROJECT_ROOT="$(cd "$INSTALL_PROJECT_ROOT" && pwd -P)"
    [[ "$INSTALL_PROJECT_ROOT" != "/" ]] \
        || install_die "refusing to use the filesystem root as a project"
    INSTALL_PREFIX="$INSTALL_PROJECT_ROOT/.reproera"
fi

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

if [[ "$INSTALL_PROJECT_MODE" -eq 1 ]]; then
    activation="$INSTALL_PREFIX/activate"
    activation_tcsh="$INSTALL_PREFIX/activate.tcsh"

    {
        printf '# Source this file from Bash or Zsh to activate this Reproera project.\n'
        printf '_reproera_project_root=%q\n' "$INSTALL_PROJECT_ROOT"
        printf 'export REPROERA_PREFIX="$_reproera_project_root/.reproera/prefix"\n'
        printf 'export REPROERA_STATE_DIR="$_reproera_project_root/.reproera/state"\n'
        printf 'export PATH="$_reproera_project_root/.reproera/bin:$_reproera_project_root/.reproera/prefix/bin:$PATH"\n'
        printf 'export PKG_CONFIG_PATH="$_reproera_project_root/.reproera/prefix/lib/pkgconfig:$_reproera_project_root/.reproera/prefix/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"\n'
        printf 'export LD_LIBRARY_PATH="$_reproera_project_root/.reproera/prefix/lib:$_reproera_project_root/.reproera/prefix/lib64:${LD_LIBRARY_PATH:-}"\n'
        printf 'unset _reproera_project_root\n'
    } >"$activation"

    escaped_project_root="$INSTALL_PROJECT_ROOT"
    escaped_project_root="${escaped_project_root//\\/\\\\}"
    escaped_project_root="${escaped_project_root//\"/\\\"}"
    escaped_project_root="${escaped_project_root//\$/\\\$}"
    escaped_project_root="${escaped_project_root//\`/\\\`}"
    escaped_project_root="${escaped_project_root//!/\\!}"
    {
        printf '# Source this file from tcsh or csh to activate this Reproera project.\n'
        printf 'setenv REPROERA_PROJECT_ROOT "%s"\n' "$escaped_project_root"
        printf 'setenv REPROERA_PREFIX "${REPROERA_PROJECT_ROOT}/.reproera/prefix"\n'
        printf 'setenv REPROERA_STATE_DIR "${REPROERA_PROJECT_ROOT}/.reproera/state"\n'
        printf 'setenv PATH "${REPROERA_PROJECT_ROOT}/.reproera/bin:${REPROERA_PROJECT_ROOT}/.reproera/prefix/bin:${PATH}"\n'
        printf 'if ( $?PKG_CONFIG_PATH ) then\n'
        printf '  setenv PKG_CONFIG_PATH "${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib/pkgconfig:${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib64/pkgconfig:${PKG_CONFIG_PATH}"\n'
        printf 'else\n'
        printf '  setenv PKG_CONFIG_PATH "${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib/pkgconfig:${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib64/pkgconfig"\n'
        printf 'endif\n'
        printf 'if ( $?LD_LIBRARY_PATH ) then\n'
        printf '  setenv LD_LIBRARY_PATH "${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib:${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib64:${LD_LIBRARY_PATH}"\n'
        printf 'else\n'
        printf '  setenv LD_LIBRARY_PATH "${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib:${REPROERA_PROJECT_ROOT}/.reproera/prefix/lib64"\n'
        printf 'endif\n'
        printf 'unsetenv REPROERA_PROJECT_ROOT\n'
    } >"$activation_tcsh"

    if [[ ! -e "$INSTALL_PREFIX/.gitignore" ]]; then
        printf '*\n!.gitignore\n' >"$INSTALL_PREFIX/.gitignore"
    fi
fi

printf '[reproera installer] installed %s\n' "$launcher"
if [[ "$INSTALL_PROJECT_MODE" -eq 1 ]]; then
    printf '[reproera installer] project root: %s\n' "$INSTALL_PROJECT_ROOT"
    printf '[reproera installer] activate with: source %s\n' "$INSTALL_PREFIX/activate"
    printf '[reproera installer] tcsh/csh: source %s\n' "$INSTALL_PREFIX/activate.tcsh"
    exit 0
fi
case ":${PATH}:" in
    *":$INSTALL_PREFIX/bin:"*) ;;
    *)
        printf '[reproera installer] add %s/bin to PATH, then run: reproera doctor\n' \
            "$INSTALL_PREFIX"
        ;;
esac
