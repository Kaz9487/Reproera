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

test_plan() {
    assert_equals "python dependency plan" "$($REPROERA plan python)" $'zlib@1.3.1\nopenssl@3.5.8\npython@3.11.16'
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
    test_unsupported_version
    printf '1..%d\n' "$TESTS_RUN"
    if [[ "$TESTS_FAILED" -ne 0 ]]; then
        printf '# %d test(s) failed\n' "$TESTS_FAILED"
        return 1
    fi
    printf '# all tests passed\n'
}

main "$@"
