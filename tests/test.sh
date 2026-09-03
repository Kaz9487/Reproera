#!/usr/bin/env bash

set -u
set -o pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPROERA="${TEST_ROOT}/bin/reproera"
TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf 'ok %d - %s\n' "$TESTS_RUN" "$1"; }
fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); printf 'not ok %d - %s\n' "$TESTS_RUN" "$1"; }

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then pass "$name"; else fail "$name (missing: $needle)"; fi
}

assert_equals() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then pass "$name"; else fail "$name (expected '$expected', got '$actual')"; fi
}

test_version() {
    assert_contains "version command" "$($REPROERA version)" "0.1.0-alpha.1"
}

test_self_install() {
    local temporary prefix installed output
    temporary="$(mktemp -d)"
    prefix="$temporary/prefix"
    installed="$prefix/bin/reproera"

    output="$(bash "$TEST_ROOT/install.sh" --prefix "$prefix")"
    assert_contains "self installer reports destination" "$output" "$installed"
    assert_equals "self installer uses relocatable link" \
        "$(readlink "$installed")" "../libexec/reproera/bin/reproera"
    assert_contains "installed CLI works outside checkout" \
        "$(cd / && HOME="$temporary" "$installed" version)" "0.1.0-alpha.1"

    bash "$TEST_ROOT/install.sh" --prefix "$prefix" >/dev/null
    assert_contains "self installer is idempotent" \
        "$(cd / && HOME="$temporary" "$installed" plan tmux)" "tmux@3.6b"
    rm -rf "$temporary"
}

test_project_self_install() {
    local temporary project checkout installed output activated_path activated_prefix
    temporary="$(mktemp -d)"
    project="$temporary/project with spaces"
    checkout="$project/Reproera"
    installed="$project/.reproera/bin/reproera"
    mkdir -p "$checkout/bin" "$checkout/lib"
    cp "$TEST_ROOT/install.sh" "$checkout/install.sh"
    cp "$TEST_ROOT/bin/reproera" "$checkout/bin/reproera"
    cp "$TEST_ROOT"/lib/*.sh "$checkout/lib/"

    output="$(HOME="$temporary/home" bash "$checkout/install.sh" --project)"
    assert_contains "project installer reports project root" "$output" "$project"
    assert_contains "project installer reports activation command" \
        "$output" "$project/.reproera/activate"
    assert_contains "project installer creates tcsh activation" \
        "$(cat "$project/.reproera/activate.tcsh")" 'setenv PATH'
    assert_contains "project installer ignores its runtime directory" \
        "$(cat "$project/.reproera/.gitignore")" '!.gitignore'
    assert_contains "project installer is idempotent" \
        "$(HOME="$temporary/home" bash "$checkout/install.sh" --project)" "$installed"

    rm -rf "$checkout"
    assert_contains "project-installed CLI works after checkout removal" \
        "$(cd "$project" && "$installed" version)" "0.1.0-alpha.1"

    activated_path="$(cd "$project" && PATH=/usr/bin:/bin bash -c \
        'source .reproera/activate; command -v reproera')"
    assert_equals "project activation exposes the CLI" "$activated_path" "$installed"
    activated_prefix="$(cd "$project" && PATH=/usr/bin:/bin bash -c \
        'source .reproera/activate; reproera env bash')"
    assert_contains "project activation selects the local package prefix" \
        "$activated_prefix" "$project/.reproera/prefix/bin"
    if [[ ! -e "$temporary/home/.local" ]]; then
        pass "project installer does not touch HOME/.local"
    else
        fail "project installer does not touch HOME/.local"
    fi

    if HOME="$temporary/home" bash "$TEST_ROOT/install.sh" --project \
        --prefix "$temporary/other" >/dev/null 2>&1; then
        fail "project and explicit prefix modes are mutually exclusive"
    else
        pass "project and explicit prefix modes are mutually exclusive"
    fi
    rm -rf "$temporary"
}

test_project_mode() {
    local temporary project second_project subdir output expected_prefix
    temporary="$(mktemp -d)"
    project="$temporary/project"
    subdir="$project/src/module"
    mkdir -p "$subdir"

    output="$(cd "$project" && "$REPROERA" init 2>&1)"
    assert_contains "project init reports root" "$output" "$project"
    assert_contains "project init pins default Python" \
        "$(cat "$project/reproera.toml")" 'python = "3.11.16"'
    assert_contains "project runtime directory is ignored" \
        "$(cat "$project/.reproera/.gitignore")" '!.gitignore'

    expected_prefix="$project/.reproera/prefix"
    assert_contains "project env selects local prefix" \
        "$(cd "$project" && "$REPROERA" env bash)" "$expected_prefix/bin"
    assert_contains "subdirectory discovers project root" \
        "$(cd "$subdir" && "$REPROERA" env bash)" "$expected_prefix/bin"
    assert_contains "explicit prefix overrides project discovery" \
        "$(cd "$subdir" && REPROERA_PREFIX="$temporary/override" "$REPROERA" env bash)" \
        "$temporary/override/bin"
    assert_equals "project plan reads reproera.toml" \
        "$(cd "$subdir" && "$REPROERA" plan)" \
        $'zlib@1.3.1\nbzip2@1.0.8\nxz@5.8.3\nlibffi@3.8.0\nsqlite@3.53.4\nopenssl@3.5.8\nncurses@6.5\nreadline@8.3\npython@3.11.16'
    assert_contains "project install supports options without a package" \
        "$(cd "$project" && "$REPROERA" install --dry-run 2>&1)" "prefix=$expected_prefix"

    printf '[environment]\npython = 3.11.16\n' >"$project/reproera.toml"
    if output="$(cd "$project" && "$REPROERA" plan 2>&1)"; then
        fail "invalid project configuration is rejected"
    else
        pass "invalid project configuration is rejected"
    fi
    assert_contains "invalid project configuration explains location" "$output" "reproera.toml:2"

    second_project="$temporary/second-project"
    mkdir -p "$second_project"
    (cd "$second_project" && "$REPROERA" init tmux@3.3a >/dev/null 2>&1)
    assert_contains "second project has an independent prefix" \
        "$(cd "$second_project" && "$REPROERA" env bash)" \
        "$second_project/.reproera/prefix/bin"
    assert_equals "second project has an independent package plan" \
        "$(cd "$second_project" && "$REPROERA" plan)" \
        $'ncurses@6.5\nlibevent@2.1.13-stable\ntmux@3.3a'
    rm -rf "$temporary"
}

test_plan() {
    assert_equals "python dependency plan" "$($REPROERA plan python)" $'zlib@1.3.1\nbzip2@1.0.8\nxz@5.8.3\nlibffi@3.8.0\nsqlite@3.53.4\nopenssl@3.5.8\nncurses@6.5\nreadline@8.3\npython@3.11.16'
    assert_equals "tmux dependency plan" "$($REPROERA plan tmux)" $'ncurses@6.5\nlibevent@2.1.13-stable\ntmux@3.6b'
}

test_dry_run() {
    local temporary output
    temporary="$(mktemp -d)"
    output="$(HOME="$temporary" "$REPROERA" install python --dry-run 2>&1)"
    assert_contains "dry run does not download" "$output" "dry run"
    assert_contains "dry run resolves package" "$output" "python@3.11.16"
    if [[ ! -e "$temporary/.local" ]]; then pass "dry run does not create prefix"; else fail "dry run does not create prefix"; fi
    rm -rf "$temporary"
}

test_prefix_scoped_markers() {
    # The same package installed to two prefixes must not share a marker.
    source "$TEST_ROOT/lib/common.sh"
    local first second
    first="$(reproera_string_sha256 /tmp/prefix-a)"
    second="$(reproera_string_sha256 /tmp/prefix-b)"
    if [[ "$first" != "$second" ]]; then pass "installation markers are prefix scoped"; else fail "installation markers are prefix scoped"; fi
}

test_environment() {
    assert_contains "bash environment" "$($REPROERA env bash)" 'export PATH='
    assert_contains "tcsh environment" "$($REPROERA env tcsh)" 'setenv PATH'
    assert_contains "tcsh init uses native syntax" "$($REPROERA shell-init tcsh)" 'setenv PATH'
}

test_doctor_json() {
    local output
    output="$($REPROERA doctor --json)" || true
    assert_contains "doctor JSON compiler" "$output" '"compiler"'
    assert_contains "doctor JSON ready" "$output" '"ready"'
}

test_compiler_matrix() {
    local temporary version output
    temporary="$(mktemp -d)"
    for version in 4.8.5 7.5.0 11.5.0 13.3.0; do
        sed "s/@VERSION@/$version/g" "$TEST_ROOT/tests/fixtures/fake-gcc.in" >"$temporary/gcc-$version"
        chmod +x "$temporary/gcc-$version"
        output="$(CC="$temporary/gcc-$version" "$REPROERA" doctor --json)" || true
        assert_contains "GCC $version detected" "$output" "\"version\": \"$version\""
    done
    rm -rf "$temporary"
}

test_compiler_edge_cases() {
    local temporary output status
    temporary="$(mktemp -d)"
    sed 's/@VERSION@/18.1.0/g' "$TEST_ROOT/tests/fixtures/fake-clang.in" >"$temporary/clang"
    chmod +x "$temporary/clang"
    output="$(CC="$temporary/clang" "$REPROERA" doctor --json)" || true
    assert_contains "Clang detected" "$output" '"kind": "clang"'

    set +e
    output="$(CC="$temporary/does-not-exist" "$REPROERA" doctor --json)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then pass "missing compiler makes doctor fail"; else fail "missing compiler makes doctor fail"; fi
    assert_contains "missing compiler reported" "$output" '"kind": "missing"'
    rm -rf "$temporary"
}

test_version_comparison() {
    source "$TEST_ROOT/lib/common.sh"
    if reproera_version_ge 4.8.5 4.8; then pass "GCC 4.8.5 satisfies 4.8"; else fail "GCC 4.8.5 satisfies 4.8"; fi
    if ! reproera_version_ge 4.7.4 4.8; then pass "GCC 4.7.4 is below 4.8"; else fail "GCC 4.7.4 is below 4.8"; fi
}

test_shell_init_apply() {
    local temporary count
    temporary="$(mktemp -d)"
    printf '# existing config\n' >"$temporary/.cshrc"
    HOME="$temporary" "$REPROERA" shell-init tcsh --apply >/dev/null 2>&1
    HOME="$temporary" "$REPROERA" shell-init tcsh --apply >/dev/null 2>&1
    count="$(grep -Fc '# Reproera' "$temporary/.cshrc")"
    assert_equals "shell init is idempotent" "$count" "1"
    if [[ -f "$temporary/.cshrc.reproera.bak" ]]; then pass "shell init writes backup"; else fail "shell init writes backup"; fi
    rm -rf "$temporary"
}

test_archive_safety() {
    source "$TEST_ROOT/lib/common.sh"
    local temporary status
    temporary="$(mktemp -d)"
    mkdir -p "$temporary/source"
    printf 'fixture\n' >"$temporary/source/payload"
    tar -czf "$temporary/unsafe.tar.gz" \
        --transform='s|^payload$|../escape|' -C "$temporary/source" payload
    set +e
    (reproera_extract_archive "$temporary/unsafe.tar.gz" "$temporary/output") >/dev/null 2>&1
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then pass "archive traversal is rejected"; else fail "archive traversal is rejected"; fi
    if [[ ! -e "$temporary/escape" ]]; then pass "unsafe archive writes nothing"; else fail "unsafe archive writes nothing"; fi
    rm -rf "$temporary"
}

test_checksum_mismatch() {
    source "$TEST_ROOT/lib/common.sh"
    local temporary archive status
    temporary="$(mktemp -d)"
    archive="$temporary/corrupt.tar.gz"
    printf 'not an archive\n' >"$archive"
    set +e
    (reproera_verify_archive "$archive" "0000000000000000000000000000000000000000000000000000000000000000") \
        >/dev/null 2>&1
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then pass "checksum mismatch is rejected"; else fail "checksum mismatch is rejected"; fi
    if [[ ! -e "$archive" ]]; then pass "corrupt cached archive is removed"; else fail "corrupt cached archive is removed"; fi
    rm -rf "$temporary"
}

test_unsupported_version() {
    local output status
    set +e
    output="$($REPROERA plan python@0.0.0 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then pass "unsupported version rejected"; else fail "unsupported version rejected"; fi
    assert_contains "unsupported version explains error" "$output" "unsupported package or version"
}

main() {
    printf 'TAP version 13\n'
    test_version
    test_self_install
    test_project_self_install
    test_project_mode
    test_plan
    test_dry_run
    test_environment
    test_prefix_scoped_markers
    test_doctor_json
    test_compiler_matrix
    test_compiler_edge_cases
    test_version_comparison
    test_shell_init_apply
    test_archive_safety
    test_checksum_mismatch
    test_unsupported_version
    printf '1..%d\n' "$TESTS_RUN"
    if [[ "$TESTS_FAILED" -ne 0 ]]; then
        printf '# %d test(s) failed\n' "$TESTS_FAILED"
        return 1
    fi
    printf '# all tests passed\n'
}

main "$@"
