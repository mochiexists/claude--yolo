#!/bin/sh
set -e

# claude-yolo uninstaller
# Removes the claude-yolo shell function from rc files

START_MARKER=">>> claude-yolo >>>"
END_MARKER="<<< claude-yolo <<<"

uninstall_from_rc() {
    rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if ! grep -q "$START_MARKER" "$rc_file" 2>/dev/null; then
        return
    fi

    # Extract the block and verify it looks like ours
    block=$(sed -n "/$START_MARKER/,/$END_MARKER/p" "$rc_file")
    block_lines=$(echo "$block" | wc -l | tr -d ' ')

    if [ "$block_lines" -gt 35 ]; then
        echo "  WARNING: Block in $rc_file has $block_lines lines (expected < 35)."
        echo "  It may have been modified. Skipping to be safe."
        echo "  Manually remove the block between '$START_MARKER' and '$END_MARKER'."
        return
    fi

    # Verify it contains our function (current or legacy format)
    if ! echo "$block" | grep -qE "__claude_yolo|command claude"; then
        echo "  WARNING: Block in $rc_file doesn't look like the claude-yolo function."
        echo "  Skipping to be safe. Manually remove the block."
        return
    fi

    # Safe to remove
    sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$rc_file"
    rm -f "${rc_file}.bak"
    echo "  Removed from $rc_file"
}

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo"
echo "  > ^ <  uninstaller"
echo ""
echo "==> Cleaning up..."

if [ -f "$HOME/.zshrc" ]; then
    uninstall_from_rc "$HOME/.zshrc"
fi

if [ -f "$HOME/.bashrc" ]; then
    uninstall_from_rc "$HOME/.bashrc"
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Uninstalled! *walks away*"
echo "  > ^ <  "
echo ""
echo "  Open a new terminal to complete removal."
echo ""
