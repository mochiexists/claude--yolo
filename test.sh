#!/bin/sh
set -e

# Test the full install → verify → uninstall → verify cycle
# Uses a temp HOME so it never touches your real rc files

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_HOME=$(mktemp -d)
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

cleanup() {
    rm -rf "$FAKE_HOME"
}
trap cleanup EXIT

echo ""
echo "=== Test: fresh install ==="
touch "$FAKE_HOME/.zshrc"
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc contains claude function" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: idempotent reinstall ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc still has exactly 1 marker" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: function works ==="
# Source the rc and check that claude function exists
result=$(zsh -c "source '$FAKE_HOME/.zshrc' && type claude" 2>&1 || true)
assert_eq "claude is a function" "1" "$(echo "$result" | grep -c 'function')"

echo ""
echo "=== Test: --yolo rewrite ==="
# Create a fake claude binary that prints its args
mkdir -p "$FAKE_HOME/bin"
cat > "$FAKE_HOME/bin/claude" << 'FAKEBIN'
#!/bin/sh
echo "$@"
FAKEBIN
chmod +x "$FAKE_HOME/bin/claude"
result=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --yolo" 2>&1)
assert_eq "--yolo becomes --dangerously-skip-permissions" "--dangerously-skip-permissions" "$result"

echo ""
echo "=== Test: other args pass through ==="
result=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --model opus --yolo --verbose" 2>&1)
assert_eq "mixed args rewritten correctly" "--model opus --dangerously-skip-permissions --verbose" "$result"

echo ""
echo "=== Test: uninstall ==="
sh "$SCRIPT_DIR/uninstall.sh"
assert_eq "zshrc has no marker after uninstall" "0" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: reinstall after uninstall ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc has marker after reinstall" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: bash support ==="
rm -f "$FAKE_HOME/.zshrc"
export SHELL="/bin/bash"
touch "$FAKE_HOME/.bashrc"
sh "$SCRIPT_DIR/uninstall.sh"
sh "$SCRIPT_DIR/install.sh"
assert_eq "bashrc contains claude function" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.bashrc")"

echo ""
echo "================================"
echo "  $passed passed, $failed failed"
echo "================================"
echo ""

[ "$failed" -eq 0 ]
