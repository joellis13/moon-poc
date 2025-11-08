#!/bin/bash
set -e

# Moon POC - Update Script
# Usage: ./update.sh [--chrome-version NEW_VERSION]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run setup in update mode
exec "$SCRIPT_DIR/setup.sh" --update "$@"