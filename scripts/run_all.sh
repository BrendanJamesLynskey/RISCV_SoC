#!/bin/bash
# Brendan Lynskey 2025
# Run all SV and CocoTB tests for RISCV_SoC
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== SystemVerilog Tests ==="
bash "$SCRIPT_DIR/run_all_sv.sh"
echo ""
echo "=== CocoTB Tests ==="
bash "$SCRIPT_DIR/run_all_cocotb.sh"
