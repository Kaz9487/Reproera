#!/usr/bin/env bash

reproera_os_id() {
    if [[ -r /etc/os-release ]]; then
        local id
        id="$(. /etc/os-release; printf '%s' "${ID:-unknown}")"
        printf '%s\n' "$id"
    else
        printf 'unknown\n'
    fi
}

reproera_os_version() {
    if [[ -r /etc/os-release ]]; then
        local version
        version="$(. /etc/os-release; printf '%s' "${VERSION_ID:-unknown}")"
        printf '%s\n' "$version"
    else
        printf 'unknown\n'
    fi
}

reproera_compiler_kind() {
    local compiler="${CC:-cc}"
    local line
    if ! reproera_command_exists "$compiler"; then
        printf 'missing\n'
        return
    fi
    line="$($compiler --version 2>/dev/null | head -n 1)"
    case "$line" in
        *clang*) printf 'clang\n' ;;
        *GCC*|*gcc*|*Free\ Software\ Foundation*) printf 'gcc\n' ;;
        *)
            if printf '\n' | "$compiler" -dM -E - 2>/dev/null | grep -q '^#define __GNUC__ '; then
                printf 'gcc\n'
            else
                printf 'unknown\n'
            fi
            ;;
    esac
}

reproera_compiler_version() {
    local compiler="${CC:-cc}"
    if ! reproera_command_exists "$compiler"; then
        printf 'missing\n'
        return
    fi
    "$compiler" -dumpfullversion -dumpversion 2>/dev/null \
        || "$compiler" -dumpversion 2>/dev/null \
        || printf 'unknown\n'
}

reproera_check_writable_prefix() {
    local prefix="$1"
    local parent="$prefix"
    while [[ ! -e "$parent" && "$parent" != "/" ]]; do
        parent="$(dirname "$parent")"
    done
    [[ -d "$parent" && -w "$parent" ]]
}

reproera_doctor_text() {
    local prefix compiler_kind compiler_version problems=0
    prefix="$(reproera_default_prefix)"
    compiler_kind="$(reproera_compiler_kind)"
    compiler_version="$(reproera_compiler_version)"

    printf 'Reproera doctor\n'
    printf '  OS:             %s %s\n' "$(reproera_os_id)" "$(reproera_os_version)"
    printf '  Architecture:   %s\n' "$(uname -m 2>/dev/null || printf unknown)"
    printf '  Shell:          %s\n' "${SHELL:-unknown}"
    printf '  Prefix:         %s\n' "$prefix"
    printf '  Compiler:       %s %s (%s)\n' "$compiler_kind" "$compiler_version" "${CC:-cc}"
    printf '  Build workers:  %s\n' "$(reproera_cpu_count)"

    local command
    for command in bash make tar awk sed sort find; do
        if reproera_command_exists "$command"; then
            printf '  [ok]   %-10s %s\n' "$command" "$(command -v "$command")"
        else
            printf '  [fail] %-10s missing\n' "$command"
            problems=$((problems + 1))
        fi
    done

    if reproera_command_exists curl || reproera_command_exists wget; then
        printf '  [ok]   downloader %s\n' "$(command -v curl 2>/dev/null || command -v wget)"
    else
        printf '  [fail] downloader curl or wget is required\n'
        problems=$((problems + 1))
    fi

    if reproera_command_exists sha256sum || reproera_command_exists shasum; then
        printf '  [ok]   checksum   available\n'
    else
        printf '  [fail] checksum   sha256sum or shasum is required\n'
        problems=$((problems + 1))
    fi

    if reproera_check_writable_prefix "$prefix"; then
        printf '  [ok]   prefix     writable\n'
    else
        printf '  [fail] prefix     not writable\n'
        problems=$((problems + 1))
    fi

    if [[ "$compiler_kind" == "missing" ]]; then
        printf '  [fail] compiler   set CC to a working C compiler\n'
        problems=$((problems + 1))
    elif [[ "$compiler_kind" == "gcc" ]] && ! reproera_version_ge "$compiler_version" "4.8"; then
        printf '  [warn] compiler   GCC 4.8 or newer is recommended\n'
    else
        printf '  [ok]   compiler   detected\n'
    fi

    if [[ "$problems" -eq 0 ]]; then
        printf '\nReady for source builds.\n'
        return 0
    fi
    printf '\nFound %s blocking problem(s).\n' "$problems"
    return 1
}

reproera_doctor_json() {
    local prefix compiler_kind compiler_version ready=true
    prefix="$(reproera_default_prefix)"
    compiler_kind="$(reproera_compiler_kind)"
    compiler_version="$(reproera_compiler_version)"
    if [[ "$compiler_kind" == "missing" ]] || ! reproera_check_writable_prefix "$prefix"; then
        ready=false
    fi
    local command
    for command in bash make tar awk sed sort find; do
        reproera_command_exists "$command" || ready=false
    done
    (reproera_command_exists curl || reproera_command_exists wget) || ready=false
    (reproera_command_exists sha256sum || reproera_command_exists shasum) || ready=false

    printf '{\n'
    printf '  "reproera_version": "%s",\n' "$(reproera_json_escape "$REPROERA_VERSION")"
    printf '  "os": {"id": "%s", "version": "%s"},\n' \
        "$(reproera_json_escape "$(reproera_os_id)")" \
        "$(reproera_json_escape "$(reproera_os_version)")"
    printf '  "architecture": "%s",\n' "$(reproera_json_escape "$(uname -m 2>/dev/null || printf unknown)")"
    printf '  "prefix": "%s",\n' "$(reproera_json_escape "$prefix")"
    printf '  "compiler": {"command": "%s", "kind": "%s", "version": "%s"},\n' \
        "$(reproera_json_escape "${CC:-cc}")" "$compiler_kind" "$(reproera_json_escape "$compiler_version")"
    printf '  "ready": %s\n' "$ready"
    printf '}\n'
    [[ "$ready" == true ]]
}

reproera_doctor() {
    case "${1:-}" in
        "") reproera_doctor_text ;;
        --json) reproera_doctor_json ;;
        *) reproera_die "unknown doctor option: $1" ;;
    esac
}
