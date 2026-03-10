#!/bin/bash
set -e

echo "=== Building Tinta4Plus ==="

echo "[1/2] Building GUI (tinta4plus)..."
pyinstaller tinta4plus.spec --noconfirm

echo "[2/2] Building Helper Daemon (tinta4plus-helper)..."
pyinstaller tinta4plus-helper.spec --noconfirm

echo ""
echo "=== Build complete ==="
echo "GUI binary:    dist/tinta4plus/tinta4plus"
echo "Helper binary: dist/tinta4plus-helper/tinta4plus-helper"
