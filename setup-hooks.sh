#!/bin/bash
set -e

# ============================================================================
# setup-hooks.sh - Configure Git to use project hooks
# ============================================================================
# Run this once after cloning:  ./setup-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔧 Configuring Git hooks..."
git -C "${SCRIPT_DIR}" config core.hooksPath .githooks
chmod +x "${SCRIPT_DIR}/.githooks/pre-push"

echo "✅ Git hooks configured."
echo "   pre-push hook will run 'swift test' before each push."
