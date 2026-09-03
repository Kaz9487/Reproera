#!/usr/bin/env bash

reproera_print_plan_recursive() {
    local package="$1"
    local version="$2"
    local dependency dep_version
    for dependency in $(reproera_recipe_dependencies "$package"); do
        dep_version="$(reproera_default_version "$dependency")"
        reproera_print_plan_recursive "$dependency" "$dep_version"
    done
    printf '%s@%s\n' "$package" "$version"
}

reproera_plan() {
    [[ "$#" -eq 1 ]] || reproera_die "usage: reproera plan PACKAGE[@VERSION]"
    local resolved package version
    resolved="$(reproera_resolve_spec "$1")" || reproera_die "unsupported package or version: $1"
    package="${resolved%% *}"
    version="${resolved#* }"
    reproera_print_plan_recursive "$package" "$version" | awk '!seen[$0]++'
}

reproera_build_one() {
    local package="$1"
    local version="$2"
    local prefix="$3"
    local jobs="$4"
    local cache_dir state_dir archive url sha source_parent source_dir marker prefix_id
    cache_dir="$(reproera_cache_dir)/sources"
    state_dir="$(reproera_state_dir)"
    archive="${cache_dir}/$(reproera_recipe_archive "$package" "$version")"
    url="$(reproera_recipe_url "$package" "$version")"
    sha="$(reproera_recipe_sha256 "$package" "$version")"
    source_parent="$(reproera_safe_build_dir "$state_dir" "$package" "$version")"
    prefix_id="$(reproera_string_sha256 "$prefix")"
    marker="${state_dir}/installed/${prefix_id}/${package}-${version}"

    if [[ -f "$marker" ]]; then
        reproera_info "$package@$version is already installed"
        return
    fi

    reproera_info "downloading $package@$version"
    reproera_download "$url" "$archive" || reproera_die "download failed: $url"
    reproera_verify_archive "$archive" "$sha"
    reproera_extract_archive "$archive" "$source_parent"
    source_dir="$(find "$source_parent" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$source_dir" ]] || reproera_die "could not locate extracted source directory"

    reproera_info "building $package@$version with ${CC:-cc}"
    if ! reproera_run_recipe "$package" "$source_dir" "$prefix" "$jobs"; then
        reproera_warn "retaining failed build tree: $source_parent"
        return 1
    fi
    reproera_verify_install "$package" "$prefix"
    mkdir -p "$(dirname "$marker")"
    printf 'prefix=%s\ninstalled_at=%s\n' "$prefix" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$marker"
}

reproera_run_recipe() {
    local package="$1" source_dir="$2" prefix="$3" jobs="$4"
    case "$package" in
        zlib)
            (cd "$source_dir" && ./configure --prefix="$prefix" && make -j"$jobs" && make install)
            ;;
        openssl)
            (cd "$source_dir" && CPPFLAGS="-I$prefix/include ${CPPFLAGS:-}" \
                LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib ${LDFLAGS:-}" \
                ./Configure --prefix="$prefix" --openssldir="$prefix/ssl" \
                --libdir=lib \
                shared zlib --with-zlib-include="$prefix/include" \
                --with-zlib-lib="$prefix/lib" && \
                make -j"$jobs" build_sw && make install_sw)
            ;;
        ncurses)
            (cd "$source_dir" && ./configure --prefix="$prefix" --with-shared \
                --without-debug --without-ada --enable-widec --enable-pc-files \
                --with-pkg-config-libdir="$prefix/lib/pkgconfig" && \
                make -j"$jobs" && make install)
            ;;
        libevent)
            (cd "$source_dir" && PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
                CPPFLAGS="-I$prefix/include ${CPPFLAGS:-}" \
                LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib ${LDFLAGS:-}" \
                ./configure --prefix="$prefix" --disable-openssl && \
                make -j"$jobs" && make install)
            ;;
        python)
            (cd "$source_dir" && CPPFLAGS="-I$prefix/include ${CPPFLAGS:-}" \
                LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib ${LDFLAGS:-}" \
                PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
                ./configure --prefix="$prefix" --with-openssl="$prefix" \
                --with-openssl-rpath=auto --with-ensurepip=install && \
                make -j"$jobs" && make altinstall)
            ;;
        tmux)
            (cd "$source_dir" && CPPFLAGS="-I$prefix/include -I$prefix/include/ncursesw ${CPPFLAGS:-}" \
                LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib ${LDFLAGS:-}" \
                PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
                ./configure --prefix="$prefix" && make -j"$jobs" && make install)
            ;;
        *) reproera_die "no build recipe for $package" ;;
    esac
}

reproera_verify_install() {
    local package="$1" prefix="$2"
    case "$package" in
        zlib)
            [[ -f "$prefix/include/zlib.h" ]] || reproera_die "zlib verification failed"
            ;;
        openssl)
            "$prefix/bin/openssl" version >/dev/null || reproera_die "OpenSSL verification failed"
            ;;
        ncurses)
            [[ -f "$prefix/include/ncursesw/ncurses.h" ]] || reproera_die "ncurses verification failed"
            ;;
        libevent)
            [[ -f "$prefix/include/event2/event.h" ]] || reproera_die "libevent verification failed"
            ;;
        python)
            "$prefix/bin/python3.11" -c 'import ssl, zlib' \
                || reproera_die "Python verification failed: ssl or zlib module unavailable"
            ;;
        tmux)
            "$prefix/bin/tmux" -V >/dev/null || reproera_die "tmux verification failed"
            ;;
    esac
}

reproera_check_plan_requirements() {
    local spec="$1" plan_line package command missing=0
    while IFS= read -r plan_line; do
        package="${plan_line%%@*}"
        for command in $(reproera_recipe_required_commands "$package"); do
            if ! reproera_command_exists "$command"; then
                reproera_warn "$package requires missing command: $command"
                missing=1
            fi
        done
        if [[ "$package" == "openssl" ]] && reproera_command_exists perl \
            && ! perl -MIPC::Cmd -MTime::Piece -e 1 >/dev/null 2>&1; then
            reproera_warn "openssl requires the Perl IPC::Cmd and Time::Piece modules"
            missing=1
        fi
    done < <(reproera_plan "$spec")
    [[ "$missing" -eq 0 ]]
}

reproera_install() {
    [[ "$#" -ge 1 ]] || reproera_die "usage: reproera install PACKAGE[@VERSION] [options]"
    local spec="$1" prefix jobs dry_run=0
    shift
    prefix="$(reproera_default_prefix)"
    jobs="$(reproera_cpu_count)"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --prefix)
                [[ "$#" -ge 2 ]] || reproera_die "--prefix requires a path"
                prefix="$2"; shift 2 ;;
            --jobs|-j)
                [[ "$#" -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || reproera_die "--jobs requires a positive integer"
                jobs="$2"; shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            *) reproera_die "unknown install option: $1" ;;
        esac
    done

    local plan_line package version canonical_prefix
    if [[ "$dry_run" -eq 1 ]]; then
        reproera_info "dry run; prefix=$prefix jobs=$jobs"
        reproera_plan "$spec"
        return
    fi

    reproera_check_writable_prefix "$prefix" || reproera_die "prefix is not writable: $prefix"
    canonical_prefix="$(reproera_realpath_dir "$prefix")"
    REPROERA_PREFIX="$canonical_prefix" reproera_doctor_text >/dev/null \
        || reproera_die "doctor found blocking problems"
    reproera_check_plan_requirements "$spec" || reproera_die "package build requirements are missing"
    while IFS= read -r plan_line; do
        package="${plan_line%%@*}"
        version="${plan_line#*@}"
        reproera_build_one "$package" "$version" "$canonical_prefix" "$jobs" \
            || reproera_die "build failed: $package@$version"
    done < <(reproera_plan "$spec")

    reproera_info "installation complete; run 'reproera env ${SHELL##*/}'"
}

reproera_emit_environment() {
    local shell_name="$1" prefix="$2"
    case "$shell_name" in
        bash|zsh)
            printf 'export PATH="%s/bin:$PATH"\n' "$prefix"
            printf 'export PKG_CONFIG_PATH="%s/lib/pkgconfig:%s/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"\n' "$prefix" "$prefix"
            printf 'export LD_LIBRARY_PATH="%s/lib:%s/lib64:${LD_LIBRARY_PATH:-}"\n' "$prefix" "$prefix"
            ;;
        tcsh|csh)
            printf 'setenv PATH "%s/bin:${PATH}"\n' "$prefix"
            printf 'if ( $?PKG_CONFIG_PATH ) then\n'
            printf '  setenv PKG_CONFIG_PATH "%s/lib/pkgconfig:%s/lib64/pkgconfig:${PKG_CONFIG_PATH}"\n' "$prefix" "$prefix"
            printf 'else\n  setenv PKG_CONFIG_PATH "%s/lib/pkgconfig:%s/lib64/pkgconfig"\nendif\n' "$prefix" "$prefix"
            printf 'if ( $?LD_LIBRARY_PATH ) then\n'
            printf '  setenv LD_LIBRARY_PATH "%s/lib:%s/lib64:${LD_LIBRARY_PATH}"\n' "$prefix" "$prefix"
            printf 'else\n  setenv LD_LIBRARY_PATH "%s/lib:%s/lib64"\nendif\n' "$prefix" "$prefix"
            ;;
        *) reproera_die "unsupported shell: $shell_name" ;;
    esac
}

reproera_emit_shell_init() {
    local shell_name="$1"
    case "$shell_name" in
        bash) printf '\n# Reproera\neval "$(reproera env bash)"\n' ;;
        zsh) printf '\n# Reproera\neval "$(reproera env zsh)"\n' ;;
        tcsh|csh)
            printf '\n# Reproera\n'
            reproera_emit_environment tcsh "$(reproera_default_prefix)"
            ;;
        *) reproera_die "unsupported shell: $shell_name" ;;
    esac
}

reproera_apply_shell_init() {
    local shell_name="$1" rc_file marker
    case "$shell_name" in
        bash) rc_file="${HOME}/.bashrc" ;;
        zsh) rc_file="${HOME}/.zshrc" ;;
        tcsh|csh) rc_file="${HOME}/.cshrc" ;;
        *) reproera_die "unsupported shell: $shell_name" ;;
    esac
    marker="# Reproera"
    if [[ -f "$rc_file" ]] && grep -Fq "$marker" "$rc_file"; then
        reproera_info "$rc_file already contains Reproera initialization"
        return
    fi
    if [[ -f "$rc_file" ]]; then
        cp -p "$rc_file" "${rc_file}.reproera.bak"
        reproera_info "backup written to ${rc_file}.reproera.bak"
    fi
    reproera_emit_shell_init "$shell_name" >>"$rc_file"
    reproera_info "updated $rc_file"
}
