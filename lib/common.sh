#!/usr/bin/env bash

# This library is sourced by bin/reproera, which prints the version.
# shellcheck disable=SC2034
REPROERA_VERSION="0.1.0-alpha.1"

reproera_info() { printf '[reproera] %s\n' "$*" >&2; }
reproera_warn() { printf '[reproera] warning: %s\n' "$*" >&2; }
reproera_die() { printf '[reproera] error: %s\n' "$*" >&2; exit 1; }

reproera_find_project_root() {
    local current parent
    current="$(cd "${1:-$PWD}" 2>/dev/null && pwd -P)" || return 1
    while true; do
        if [[ -f "$current/reproera.toml" ]]; then
            printf '%s\n' "$current"
            return 0
        fi
        [[ "$current" != "/" ]] || return 1
        parent="$(dirname "$current")"
        [[ "$parent" != "$current" ]] || return 1
        current="$parent"
    done
}

reproera_default_prefix() {
    local project_root
    if [[ -n "${REPROERA_PREFIX:-}" ]]; then
        printf '%s\n' "$REPROERA_PREFIX"
    elif project_root="$(reproera_find_project_root)"; then
        printf '%s/.reproera/prefix\n' "$project_root"
    else
        printf '%s/.local\n' "$HOME"
    fi
}

reproera_state_dir() {
    local project_root
    if [[ -n "${REPROERA_STATE_DIR:-}" ]]; then
        printf '%s\n' "$REPROERA_STATE_DIR"
    elif project_root="$(reproera_find_project_root)"; then
        printf '%s/.reproera/state\n' "$project_root"
    else
        printf '%s/.local/share/reproera\n' "$HOME"
    fi
}

reproera_cache_dir() {
    printf '%s\n' "${REPROERA_CACHE_DIR:-${HOME}/.cache/reproera}"
}

reproera_cpu_count() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n'
    else
        printf '1\n'
    fi
}

reproera_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

reproera_version_ge() {
    local actual="$1"
    local required="$2"
    local first
    first="$(printf '%s\n%s\n' "$required" "$actual" | sort -V 2>/dev/null | head -n 1)" || return 1
    [[ "$first" == "$required" ]]
}

reproera_sha256() {
    local file="$1"
    if reproera_command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
    elif reproera_command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        reproera_die "sha256sum or shasum is required"
    fi
}

reproera_string_sha256() {
    local value="$1"
    if reproera_command_exists sha256sum; then
        printf '%s' "$value" | sha256sum | awk '{print $1}'
    elif reproera_command_exists shasum; then
        printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
    else
        reproera_die "sha256sum or shasum is required"
    fi
}

reproera_download() {
    local url="$1"
    local destination="$2"
    local temporary="${destination}.part"

    mkdir -p "$(dirname "$destination")"
    if [[ -f "$destination" ]]; then
        reproera_info "using cached $(basename "$destination")"
        return
    fi

    if reproera_command_exists curl; then
        curl --fail --location --retry 3 --connect-timeout 20 \
            --output "$temporary" "$url" || {
            rm -f "$temporary"
            return 1
        }
    elif reproera_command_exists wget; then
        wget --tries=3 --timeout=20 --output-document="$temporary" "$url" || {
            rm -f "$temporary"
            return 1
        }
    else
        reproera_die "curl or wget is required to download sources"
    fi
    mv "$temporary" "$destination"
}

reproera_verify_archive() {
    local archive="$1"
    local expected="$2"
    local actual
    actual="$(reproera_sha256 "$archive")"
    if [[ "$actual" != "$expected" ]]; then
        rm -f "$archive"
        reproera_die "checksum mismatch for $(basename "$archive"): expected $expected, got $actual"
    fi
}

reproera_extract_archive() {
    local archive="$1"
    local destination="$2"
    local member
    tar -tf "$archive" >/dev/null || reproera_die "cannot read archive: $archive"
    while IFS= read -r member; do
        case "$member" in
            /*|../*|*/../*|*/..)
                reproera_die "unsafe archive member: $member"
                ;;
        esac
    done < <(tar -tf "$archive")
    mkdir -p "$destination"
    case "$archive" in
        *.tar.gz|*.tgz) tar --no-same-owner -xzf "$archive" -C "$destination" ;;
        *.tar.xz) tar --no-same-owner -xJf "$archive" -C "$destination" ;;
        *) reproera_die "unsupported archive format: $archive" ;;
    esac
}

reproera_safe_build_dir() {
    local state_dir="$1"
    local package="$2"
    local version="$3"
    local build_root="${state_dir}/build"
    mkdir -p "$build_root"
    mktemp -d "${build_root}/${package}-${version}.XXXXXXXX"
}

reproera_json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '%s' "$value"
}

reproera_realpath_dir() {
    local path="$1"
    mkdir -p "$path"
    (cd "$path" && pwd -P)
}
