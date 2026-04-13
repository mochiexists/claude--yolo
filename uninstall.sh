#!/bin/sh
set -e

# claude-yolo uninstaller
# Removes the claude-yolo shell function from rc files

MARKER="claude-yolo"

uninstall_from_rc() {
    rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if ! grep -q "$MARKER" "$rc_file" 2>/dev/null; then
        return
    fi
    # Remove the block between the marker comment and the closing brace
    sed -i.bak '/# claude-yolo: --yolo flag support/,/^}/d' "$rc_file"
    # Clean up any trailing blank lines left behind
    sed -i.bak -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc_file"
    rm -f "${rc_file}.bak"
    echo "  Removed from $rc_file"
}

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo"
echo "  > ^ <  uninstaller"
echo ""
echo "==> Cleaning up..."

removed=0

if [ -f "$HOME/.zshrc" ]; then
    uninstall_from_rc "$HOME/.zshrc"
    removed=1
fi

if [ -f "$HOME/.bashrc" ]; then
    uninstall_from_rc "$HOME/.bashrc"
    removed=1
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Uninstalled! *walks away*"
echo "  > ^ <  "
echo ""
echo "  Open a new terminal to complete removal."
echo ""
