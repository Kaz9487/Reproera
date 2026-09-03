#!/usr/bin/env bash

reproera_default_version() {
    case "$1" in
        zlib) printf '1.3.1\n' ;;
        bzip2) printf '1.0.8\n' ;;
        xz) printf '5.8.3\n' ;;
        libffi) printf '3.8.0\n' ;;
        sqlite) printf '3.53.4\n' ;;
        openssl) printf '3.5.8\n' ;;
        ncurses) printf '6.5\n' ;;
        readline) printf '8.3\n' ;;
        libevent) printf '2.1.13-stable\n' ;;
        python) printf '3.11.16\n' ;;
        tmux) printf '3.6b\n' ;;
        gcc) printf '11.5.0\n' ;;
        *) return 1 ;;
    esac
}

reproera_package_status() {
    case "$1" in
        zlib|bzip2|xz|libffi|sqlite|openssl|ncurses|readline|libevent|python|tmux) printf 'source recipe\n' ;;
        gcc) printf 'diagnostics only (bootstrap planned)\n' ;;
        *) return 1 ;;
    esac
}

reproera_recipe_dependencies() {
    case "$1" in
        readline) printf '%s\n' ncurses ;;
        python) printf '%s\n' zlib bzip2 xz libffi sqlite openssl readline ;;
        tmux) printf '%s\n' ncurses libevent ;;
        *) return 0 ;;
    esac
}

reproera_recipe_required_commands() {
    case "$1" in
        openssl) printf '%s\n' perl ;;
        tmux) printf '%s\n' yacc ;;
        *) return 0 ;;
    esac
}

reproera_recipe_url() {
    local package="$1"
    local version="$2"
    case "${package}@${version}" in
        zlib@1.3.1) printf 'https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz\n' ;;
        bzip2@1.0.8) printf 'https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz\n' ;;
        xz@5.8.3) printf 'https://github.com/tukaani-project/xz/releases/download/v5.8.3/xz-5.8.3.tar.xz\n' ;;
        libffi@3.8.0) printf 'https://github.com/libffi/libffi/releases/download/v3.8.0/libffi-3.8.0.tar.gz\n' ;;
        sqlite@3.53.4) printf 'https://www.sqlite.org/2026/sqlite-autoconf-3530400.tar.gz\n' ;;
        openssl@3.5.8) printf 'https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz\n' ;;
        ncurses@6.5) printf 'https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.5.tar.gz\n' ;;
        readline@8.3) printf 'https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz\n' ;;
        libevent@2.1.13-stable) printf 'https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz\n' ;;
        python@3.11.16) printf 'https://www.python.org/ftp/python/3.11.16/Python-3.11.16.tar.xz\n' ;;
        python@3.11.9) printf 'https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tar.xz\n' ;;
        tmux@3.6b) printf 'https://github.com/tmux/tmux/releases/download/3.6b/tmux-3.6b.tar.gz\n' ;;
        tmux@3.3a) printf 'https://github.com/tmux/tmux/releases/download/3.3a/tmux-3.3a.tar.gz\n' ;;
        *) return 1 ;;
    esac
}

reproera_recipe_sha256() {
    local package="$1"
    local version="$2"
    case "${package}@${version}" in
        zlib@1.3.1) printf '9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23\n' ;;
        bzip2@1.0.8) printf 'ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269\n' ;;
        xz@5.8.3) printf 'fff1ffcf2b0da84d308a14de513a1aa23d4e9aa3464d17e64b9714bfdd0bbfb6\n' ;;
        libffi@3.8.0) printf '7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4\n' ;;
        sqlite@3.53.4) printf '0e9483900e92cd5de8fd48d16bf9200145a61f7fd5be542a5ac81d8a9516eb9c\n' ;;
        openssl@3.5.8) printf 'a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2\n' ;;
        ncurses@6.5) printf '136d91bc269a9a5785e5f9e980bc76ab57428f604ce3e5a5a90cebc767971cc6\n' ;;
        readline@8.3) printf 'fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc\n' ;;
        libevent@2.1.13-stable) printf 'f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c\n' ;;
        python@3.11.16) printf '91bcdebfdde239a003ae93738a7fce0f9230fee5c4bc2b86f6e6e8c6f98aabe8\n' ;;
        python@3.11.9) printf '9b1e896523fc510691126c864406d9360a3d1e986acbda59cda57b5abda45b87\n' ;;
        tmux@3.6b) printf '390759d25fdba016887ec982b808927e637070fd7d03a8021f8ef3102b9ae3c7\n' ;;
        tmux@3.3a) printf 'e4fd347843bd0772c4f48d6dde625b0b109b7a380ff15db21e97c11a4dcdf93f\n' ;;
        *) return 1 ;;
    esac
}

reproera_recipe_archive() {
    local url
    url="$(reproera_recipe_url "$1" "$2")" || return 1
    printf '%s\n' "${url##*/}"
}

reproera_project_specs() {
    local project_root config
    project_root="$(reproera_find_project_root)" \
        || reproera_die "no reproera.toml found in this directory or its parents"
    config="$project_root/reproera.toml"

    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        BEGIN { section = ""; count = 0 }
        {
            line = trim($0)
            if (line == "" || line ~ /^#/) next
            if (line ~ /^\[[^]]+\]$/) {
                section = line
                next
            }
            if (section != "[environment]") next
            if (line !~ /^[a-z][a-z0-9_-]*[[:space:]]*=[[:space:]]*"[^"]+"$/) {
                printf "[reproera] error: invalid environment entry at %s:%d\n", FILENAME, NR > "/dev/stderr"
                exit 2
            }
            key = line
            sub(/[[:space:]]*=.*/, "", key)
            value = line
            sub(/^[^=]*=[[:space:]]*"/, "", value)
            sub(/"$/, "", value)
            print key "@" value
            count++
        }
        END {
            if (count == 0) {
                printf "[reproera] error: no packages declared in [environment]\n" > "/dev/stderr"
                exit 3
            }
        }
    ' "$config"
}

reproera_resolve_spec() {
    local spec="$1"
    local package version
    if [[ "$spec" == *@* ]]; then
        package="${spec%%@*}"
        version="${spec#*@}"
    else
        package="$spec"
        version="$(reproera_default_version "$package")" || return 1
    fi
    [[ -n "$package" && -n "$version" ]] || return 1
    reproera_recipe_url "$package" "$version" >/dev/null 2>&1 || return 1
    printf '%s %s\n' "$package" "$version"
}
