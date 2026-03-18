#!/bin/bash
# Brendan Lynskey 2025
# Run all CocoTB testbenches for RISCV_SoC

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
COCOTB="$ROOT/tb/cocotb"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
FAILED=0

for dir in "$COCOTB"/test_*/; do
    name=$(basename "$dir")
    echo ""
    echo "===== $name ====="
    cd "$dir"
    if make clean > /dev/null 2>&1 && make SIM=icarus 2>&1; then
        echo -e "${GREEN}$name: PASSED${NC}"
    else
        echo -e "${RED}$name: FAILED${NC}"
        FAILED=1
    fi
done

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL COCOTB TESTS PASSED${NC}"
else
    echo -e "${RED}SOME COCOTB TESTS FAILED${NC}"
    exit 1
fi
