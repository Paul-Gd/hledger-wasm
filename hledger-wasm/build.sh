#!/bin/bash
# Build hledger-wasm for the browser
#
# Prerequisites:
#   - ghc-wasm-meta installed (provides wasm32-wasi-cabal, wasm32-wasi-ghc)
#   - Run: curl https://gitlab.haskell.org/ghc/ghc-wasm-meta/-/raw/master/bootstrap.sh | PREFIX=/tmp/ghc-wasm sh
#   - Source the environment: source /tmp/ghc-wasm/env

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for wasm32-wasi-cabal
if ! command -v wasm32-wasi-cabal &> /dev/null; then
    echo "Error: wasm32-wasi-cabal not found"
    echo ""
    echo "Install ghc-wasm-meta first:"
    echo "  curl https://gitlab.haskell.org/ghc/ghc-wasm-meta/-/raw/master/bootstrap.sh | PREFIX=/tmp/ghc-wasm sh"
    echo "  source /tmp/ghc-wasm/env"
    exit 1
fi

echo "Building hledger-wasm..."
wasm32-wasi-cabal build hledger-wasm

# Find and copy the built WASM file
WASM_FILE=$(find dist-newstyle -name "hledger-wasm.wasm" -type f | head -1)
if [ -z "$WASM_FILE" ]; then
    echo "Error: hledger-wasm.wasm not found in dist-newstyle"
    exit 1
fi

mkdir -p dist
cp "$WASM_FILE" dist/hledger-wasm.wasm

echo ""
echo "Build complete!"
echo "WASM file: dist/hledger-wasm.wasm"
echo "Size: $(ls -lh dist/hledger-wasm.wasm | awk '{print $5}')"
