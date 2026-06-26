#!/usr/bin/env bash
# tests/run.sh — Run the nvim config test suite headlessly.
#
# Usage:
#   ./tests/run.sh                  # run all specs
#   ./tests/run.sh capabilities     # run one spec by name
#
# Requirements: nvim in PATH

set -euo pipefail

NVIM_CONFIG="$(cd "$(dirname "$0")/.." && pwd)"
SPECS_DIR="$NVIM_CONFIG/tests/spec"
INIT="$NVIM_CONFIG/tests/minimal_init.lua"

# Colours
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'
BOLD='\033[1m'

pass_files=0
fail_files=0

run_spec() {
	local spec_file="$1"
	local spec_name
	spec_name=$(basename "$spec_file" .lua)

	local output
	local exit_code=0

	output=$(nvim --headless --noplugin \
		-u "$INIT" \
		-c "lua dofile('$spec_file')" \
		-c 'qa!' 2>&1) || exit_code=$?

	# Print spec output (already coloured by the spec file itself)
	echo "$output"

	if [ $exit_code -ne 0 ]; then
		echo -e "  ${RED}${BOLD}SPEC FAILED${RESET}: $spec_name (exit $exit_code)"
		fail_files=$((fail_files + 1))
	elif echo "$output" | grep -q 'FAIL\|Error\|ERROR'; then
		echo -e "  ${RED}${BOLD}SPEC HAD FAILURES${RESET}: $spec_name"
		fail_files=$((fail_files + 1))
	else
		pass_files=$((pass_files + 1))
	fi
}

echo -e "\n${BOLD}Neovim config test suite${RESET}"
echo "Config: $NVIM_CONFIG"
echo "---"

if [ $# -gt 0 ]; then
	# Run a specific spec
	spec="$SPECS_DIR/${1}_spec.lua"
	if [ ! -f "$spec" ]; then
		echo -e "${RED}Spec not found: $spec${RESET}"
		exit 1
	fi
	run_spec "$spec"
else
	# Run all specs in dependency order
	for spec in \
		"$SPECS_DIR/capabilities_spec.lua" \
		"$SPECS_DIR/state_spec.lua" \
		"$SPECS_DIR/articulation_spec.lua" \
		"$SPECS_DIR/language_spec.lua" \
		"$SPECS_DIR/plugin_deps_spec.lua" \
		"$SPECS_DIR/module_registration_spec.lua" \
		"$SPECS_DIR/review_url_spec.lua" \
		"$SPECS_DIR/debugging_spec.lua" \
		"$SPECS_DIR/keymap_spec.lua"; do
		if [ -f "$spec" ]; then
			run_spec "$spec"
		fi
	done
fi

echo ""
echo "---"
total=$((pass_files + fail_files))
if [ $fail_files -eq 0 ]; then
	echo -e "${GREEN}${BOLD}All $total spec files passed${RESET}"
	exit 0
else
	echo -e "${RED}${BOLD}$fail_files/$total spec files failed${RESET}"
	exit 1
fi
