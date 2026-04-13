#!/bin/sh
set -e

# End-to-end test for claude --yolo
# Flow: clean slate → verify broken → install → verify working → uninstall → verify broken
# Always ends in uninstalled state so you can re-run or install fresh after

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_HOME=$(mktemp -d)
REAL_HOME="$HOME"
export HOME="$FAKE_HOME"
export SHELL="/bin/zsh"

passed=0
failed=0

assert_eq() {
    label="$1"; expected="$2"; actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        failed=$((failed + 1))
    fi
}

assert_contains() {
    label="$1"; needle="$2"; haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected to contain: $needle"
        echo "    actual: $haystack"
        failed=$((failed + 1))
    fi
}

assert_not_contains() {
    label="$1"; needle="$2"; haystack="$3"
    if ! echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected NOT to contain: $needle"
        echo "    actual: $haystack"
        failed=$((failed + 1))
    fi
}

count_matches() {
    result=$(grep -c "$1" "$2" 2>/dev/null) || result=0
    printf "%s" "$result"
}

cleanup() {
    rm -rf "$FAKE_HOME"
}
trap cleanup EXIT

# Find the real claude binary
REAL_CLAUDE="$(HOME="$REAL_HOME" command -v claude 2>/dev/null || true)"
if [ -z "$REAL_CLAUDE" ]; then
    echo "ABORT: claude binary not found on PATH — can't run e2e tests"
    exit 1
fi

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo test suite"
echo "  > ^ <  "
echo ""
echo "  Using real claude at: $REAL_CLAUDE"
echo ""

# ─────────────────────────────────────────────
# Step 1: Check if --yolo exists natively
# ─────────────────────────────────────────────
echo "=== Step 1: Check claude has no native --yolo ==="
direct_version=$("$REAL_CLAUDE" --version 2>&1 || true)
assert_contains "claude binary exists and returns version" "[0-9]\.[0-9]" "$direct_version"
echo ""

# ─────────────────────────────────────────────
# Step 2: Clean slate — remove any existing install
# ─────────────────────────────────────────────
echo "=== Step 2: Ensure clean slate ==="
touch "$FAKE_HOME/.zshrc"
sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
assert_eq "zshrc has no claude-yolo marker" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 3: Try claude --yolo without install — should fail
# ─────────────────────────────────────────────
echo "=== Step 3: verify --yolo is not natively --dangerously-skip-permissions ==="
# Without the function, --yolo is just passed literally — not rewritten
# We verify the function is what does the rewriting by checking claude has no function loaded
no_func=$(zsh -c "source '$FAKE_HOME/.zshrc' && type claude" 2>&1 || true)
assert_not_contains "claude is not a function without install" "function" "$no_func"
echo ""

# ─────────────────────────────────────────────
# Step 4: Install
# ─────────────────────────────────────────────
echo "=== Step 4: Install claude --yolo ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc has claude-yolo marker" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"

# Verify the installed block is exactly what we expect (no extra content)
EXPECTED_BLOCK='# >>> claude-yolo >>>
# https://github.com/mochiexists/yolo
claude() {
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--yolo" ]]; then
            args+=("--dangerously-skip-permissions")
        else
            args+=("$arg")
        fi
    done
    command claude "${args[@]}"
}
# <<< claude-yolo <<<'
ACTUAL_BLOCK=$(sed -n '/>>> claude-yolo >>>/,/<<< claude-yolo <<</p' "$FAKE_HOME/.zshrc")
assert_eq "installed block matches expected exactly" "$EXPECTED_BLOCK" "$ACTUAL_BLOCK"

# Count lines between markers — should be exactly 14 (markers + function)
block_lines=$(echo "$ACTUAL_BLOCK" | wc -l | tr -d ' ')
assert_eq "block has exactly 14 lines" "14" "$block_lines"
echo ""

# ─────────────────────────────────────────────
# Step 5: claude --yolo works after install
# ─────────────────────────────────────────────
echo "=== Step 5: claude --yolo works after install ==="

# Version through function matches direct
func_version=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --version" 2>&1 || true)
assert_eq "claude --version through function matches direct" "$direct_version" "$func_version"

# --yolo --version should succeed and match --dangerously-skip-permissions --version
yolo_version=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --yolo --version" 2>&1 || true)
dsp_version=$("$REAL_CLAUDE" --dangerously-skip-permissions --version 2>&1 || true)
assert_eq "claude --yolo --version matches claude --dangerously-skip-permissions --version" "$dsp_version" "$yolo_version"
assert_contains "yolo version output has version number" "[0-9]\.[0-9]" "$yolo_version"

# Mixed args
mkdir -p "$FAKE_HOME/bin"
cat > "$FAKE_HOME/bin/claude" << 'FAKEBIN'
#!/bin/sh
echo "$@"
FAKEBIN
chmod +x "$FAKE_HOME/bin/claude"
mixed=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --model opus --yolo --verbose" 2>&1)
assert_eq "mixed args rewritten correctly" "--model opus --dangerously-skip-permissions --verbose" "$mixed"

# Idempotent reinstall
sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1
assert_eq "reinstall doesn't duplicate" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 6: Uninstall and verify it's gone
# ─────────────────────────────────────────────
echo "=== Step 6: Uninstall and verify removal ==="
sh "$SCRIPT_DIR/uninstall.sh"
assert_eq "zshrc has no marker after uninstall" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
assert_not_contains "zshrc has no claude function" "command claude" "$(cat "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────
echo "================================"
echo "  $passed passed, $failed failed"
echo "================================"
echo ""

if [ "$failed" -eq 0 ]; then
    echo "  /\\_/\\  "
    echo " ( ^.^ ) All tests passed! meow~"
    echo "  > ^ <  "
    echo ""
    echo "  Tests ended in uninstalled state."
    echo "  To install for real, run:"
    echo ""
    echo "    sh $SCRIPT_DIR/install.sh"
    echo ""
else
    echo "  /\\_/\\  "
    echo " ( x.x ) Some tests failed!"
    echo "  > ^ <  "
    echo ""
fi

[ "$failed" -eq 0 ]
