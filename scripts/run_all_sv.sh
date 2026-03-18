#!/bin/bash
# Brendan Lynskey 2025
# Run all SystemVerilog testbenches for RISCV_SoC
# Usage: ./scripts/run_all_sv.sh [module]
#   No args = run all; module = run just that one

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
RTL="$ROOT/rtl"
TB="$ROOT/tb/sv"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0

run_tb() {
    local name="$1"
    shift
    local files=("$@")

    echo ""
    echo "===== $name ====="
    local vvp_file="/tmp/sim_${name}.vvp"

    if iverilog -g2012 -Wall -o "$vvp_file" "${files[@]}" 2>&1; then
        local output
        output=$(vvp "$vvp_file" 2>&1)
        echo "$output"

        local p=$(echo "$output" | grep -c "\[PASS\]" || true)
        local f=$(echo "$output" | grep -c "\[FAIL\]" || true)
        TOTAL_PASS=$((TOTAL_PASS + p))
        TOTAL_FAIL=$((TOTAL_FAIL + f))

        if [ "$f" -gt 0 ]; then
            echo -e "${RED}$name: $p passed, $f FAILED${NC}"
        else
            echo -e "${GREEN}$name: $p passed${NC}"
        fi
    else
        echo -e "${RED}$name: COMPILATION FAILED${NC}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi

    rm -f "$vvp_file"
}

# Module testbenches
if [ -z "$1" ] || [ "$1" = "sys_reset" ]; then
    run_tb "sys_reset" "$RTL/sys_reset.sv" "$TB/tb_sys_reset.sv"
fi

if [ -z "$1" ] || [ "$1" = "plic" ]; then
    run_tb "plic" "$RTL/plic.sv" "$TB/tb_plic.sv"
fi

if [ -z "$1" ] || [ "$1" = "axi_sram" ]; then
    run_tb "axi_sram" "$RTL/axi_sram.sv" "$TB/tb_axi_sram.sv"
fi

# Summary
echo ""
echo "========================================"
echo "TOTAL: $TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "${RED}SOME TESTS FAILED${NC}"
    exit 1
fi
