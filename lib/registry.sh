#!/usr/bin/env bash

reproera_default_version() {
    case "$1" in
        zlib) printf '1.3.1\n' ;;
        openssl) printf '3.5.8\n' ;;
        ncurses) printf '6.5\n' ;;
        libevent) printf '2.1.13-stable\n' ;;
        python) printf '3.11.16\n' ;;
        tmux) printf '3.6b\n' ;;
        gcc) printf '11.5.0\n' ;;
        *) return 1 ;;
    esac
}

reproera_package_status() {
    case "$1" in
        zlib|openssl|ncurses|libevent|python|tmux) printf 'source recipe\n' ;;
        gcc) printf 'diagnostics only (bootstrap planned)\n' ;;
        *) return 1 ;;
    esac
}

reproera_recipe_dependencies() {
    case "$1" in
        python) printf '%s\n' zlib openssl ;;
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
        openssl@3.5.8) printf 'https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz\n' ;;
        ncurses@6.5) printf 'https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.5.tar.gz\n' ;;
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
        openssl@3.5.8) printf 'a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2\n' ;;
        ncurses@6.5) printf '136d91bc269a9a5785e5f9e980bc76ab57428f604ce3e5a5a90cebc767971cc6\n' ;;
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
