# ISBP - IPFS Station Beacon Protocol
# Makefile for common operations
#
# License: AGPL-3.0

.PHONY: all help init test test-quick test-verbose clean demo \
        beacon keys economy cooperative check-deps install-deps \
        sim sim-small sim-medium sim-large sim-json sim-html

# Default target
all: help

# Project paths
PROJECT_DIR := $(shell pwd)
TOOLS_DIR := $(PROJECT_DIR)/tools
TESTS_DIR := $(PROJECT_DIR)/tests
EXAMPLES_DIR := $(PROJECT_DIR)/examples
ISBP_DIR := $(HOME)/.isbp

################################################################################
# Help
################################################################################
help:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════════╗"
	@echo "║  ISBP - IPFS Station Beacon Protocol                          ║"
	@echo "║  Makefile Commands                                            ║"
	@echo "╚═══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Setup & Installation:"
	@echo "    make check-deps     Check required dependencies"
	@echo "    make install-deps   Install dependencies (Debian/Ubuntu)"
	@echo "    make init           Initialize ISBP environment"
	@echo ""
	@echo "  Testing:"
	@echo "    make test           Run all tests"
	@echo "    make test-quick     Run tests (quiet mode)"
	@echo "    make test-verbose   Run tests with detailed output"
	@echo ""
	@echo "  Demo & Tools:"
	@echo "    make demo           Run complete demo sequence"
	@echo "    make keys           Generate demo keys"
	@echo "    make beacon         Start beacon server"
	@echo "    make economy        Run ZEN economy cycle"
	@echo "    make cooperative    Run cooperative allocation"
	@echo ""
	@echo "  Simulation:"
	@echo "    make sim            Run constellation economic simulation"
	@echo "    make sim-small      Small satellite (100 users, 1 station)"
	@echo "    make sim-medium     Regional constellation (500 users)"
	@echo "    make sim-large      Mega constellation (2000 users)"
	@echo "    make sim-json       Output simulation as JSON"
	@echo "    make sim-html       Open interactive HTML simulator"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make clean          Clean generated files"
	@echo "    make clean-all      Clean everything (including ~/.isbp)"
	@echo ""

################################################################################
# Dependencies
################################################################################
check-deps:
	@echo "Checking dependencies..."
	@echo ""
	@command -v ipfs >/dev/null 2>&1 && echo "  ✓ ipfs" || echo "  ✗ ipfs (required)"
	@command -v python3 >/dev/null 2>&1 && echo "  ✓ python3" || echo "  ✗ python3 (required)"
	@command -v bc >/dev/null 2>&1 && echo "  ✓ bc" || echo "  ✗ bc (required)"
	@command -v nc >/dev/null 2>&1 && echo "  ✓ nc (netcat)" || echo "  ✗ nc (required for beacon)"
	@command -v curl >/dev/null 2>&1 && echo "  ✓ curl" || echo "  ⚠ curl (optional)"
	@command -v jq >/dev/null 2>&1 && echo "  ✓ jq" || echo "  ⚠ jq (optional)"
	@test -x $(TOOLS_DIR)/keygen && echo "  ✓ keygen" || echo "  ⚠ keygen (build from source)"
	@echo ""
	@echo "Python packages:"
	@python3 -c "import base58" 2>/dev/null && echo "  ✓ base58" || echo "  ✗ base58 (pip install base58)"
	@python3 -c "import cryptography" 2>/dev/null && echo "  ✓ cryptography" || echo "  ✗ cryptography (pip install cryptography)"
	@echo ""

install-deps:
	@echo "Installing system dependencies (requires sudo)..."
	sudo apt-get update
	sudo apt-get install -y bc netcat curl jq python3 python3-pip
	@echo ""
	@echo "Installing Python dependencies..."
	pip3 install base58 cryptography
	@echo ""
	@echo "Note: IPFS and keygen must be installed separately."
	@echo "  IPFS: https://docs.ipfs.io/install/"
	@echo "  keygen: https://git.p2p.legal/Astroport.ONE/keygen"

################################################################################
# Initialization
################################################################################
init: check-deps
	@echo ""
	@echo "Initializing ISBP environment..."
	@mkdir -p $(ISBP_DIR)/wallets
	@mkdir -p $(ISBP_DIR)/logs
	@mkdir -p $(ISBP_DIR)/swarm
	@mkdir -p $(ISBP_DIR)/multipass
	@mkdir -p $(ISBP_DIR)/secrets
	@chmod 700 $(ISBP_DIR)/secrets
	@echo ""
	@echo "Running UPlanet initialization..."
	@bash $(TOOLS_DIR)/uplanet_init.sh DEMO_ORIGIN
	@echo ""
	@echo "ISBP environment initialized at $(ISBP_DIR)"

################################################################################
# Testing
################################################################################
test:
	@chmod +x $(TESTS_DIR)/*.sh
	@bash $(TESTS_DIR)/run_all.sh

test-quick:
	@chmod +x $(TESTS_DIR)/*.sh
	@bash $(TESTS_DIR)/run_all.sh --quiet

test-verbose:
	@chmod +x $(TESTS_DIR)/*.sh
	@bash $(TESTS_DIR)/run_all.sh --verbose

################################################################################
# Demo & Tools
################################################################################
demo: init
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  ISBP Demo Sequence"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "1. Generating demo keys..."
	@bash $(EXAMPLES_DIR)/generate_keys.sh demo_salt demo_pepper
	@echo ""
	@echo "2. Setting up demo wallets with initial balances..."
	@echo "500" > $(ISBP_DIR)/wallets/uplanet.CASH.balance
	@echo "200" > $(ISBP_DIR)/wallets/uplanet.ASSETS.balance
	@echo "100" > $(ISBP_DIR)/wallets/uplanet.RnD.balance
	@echo "300" > $(ISBP_DIR)/wallets/uplanet.captain.balance
	@echo "0" > $(ISBP_DIR)/wallets/uplanet.IMPOT.balance
	@echo "0" > $(ISBP_DIR)/wallets/secret.NODE.balance
	@echo "0" > $(ISBP_DIR)/wallets/captain.MULTIPASS.balance
	@echo ""
	@echo "Initial balances:"
	@echo "  uplanet.CASH:     500 Ẑen"
	@echo "  uplanet.ASSETS:   200 Ẑen"
	@echo "  uplanet.RnD:      100 Ẑen"
	@echo "  uplanet.captain:  300 Ẑen (surplus for allocation)"
	@echo ""
	@echo "3. Running cooperative allocation (300 Ẑen surplus)..."
	@rm -f $(ISBP_DIR)/.cooperative_allocation.done
	@bash $(TOOLS_DIR)/zen_cooperative.sh 2>/dev/null || true
	@echo ""
	@echo "4. Running economy cycle (PAF payments)..."
	@rm -f $(ISBP_DIR)/.weekly_payment.done
	@bash $(TOOLS_DIR)/zen_economy.sh 2>/dev/null || true
	@echo ""
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Demo Complete - Final Balances"
	@echo "═══════════════════════════════════════════════════════════"
	@$(MAKE) --no-print-directory show-balances

keys:
	@echo "Generating keys (use: make keys SALT=xxx PEPPER=yyy)"
	@bash $(EXAMPLES_DIR)/generate_keys.sh $(SALT) $(PEPPER)

beacon:
	@echo "Starting beacon server on port 12345..."
	@bash $(PROJECT_DIR)/beacon.sh 12345

economy:
	@rm -f $(ISBP_DIR)/.weekly_payment.done
	@bash $(TOOLS_DIR)/zen_economy.sh

cooperative:
	@rm -f $(ISBP_DIR)/.cooperative_allocation.done
	@bash $(TOOLS_DIR)/zen_cooperative.sh

show-balances:
	@echo ""
	@echo "Current wallet balances ($(ISBP_DIR)/wallets/):"
	@echo ""
	@for f in $(ISBP_DIR)/wallets/*.balance; do \
		if [ -f "$$f" ]; then \
			name=$$(basename "$$f" .balance); \
			balance=$$(cat "$$f"); \
			printf "  %-25s %s Ẑen\n" "$$name:" "$$balance"; \
		fi \
	done
	@echo ""
	@total=$$(cat $(ISBP_DIR)/wallets/*.balance 2>/dev/null | paste -sd+ | bc -l 2>/dev/null || echo "0"); \
	echo "  ─────────────────────────────────"
	@printf "  %-25s %s Ẑen\n" "TOTAL:" "$$total"
	@echo ""

################################################################################
# Cleanup
################################################################################
clean:
	@echo "Cleaning generated files..."
	@rm -f $(ISBP_DIR)/.weekly_payment.done
	@rm -f $(ISBP_DIR)/.cooperative_allocation.done
	@rm -f $(ISBP_DIR)/logs/*.log
	@rm -rf /tmp/isbp_test_*
	@echo "Done."

clean-all: clean
	@echo "Removing all ISBP data..."
	@rm -rf $(ISBP_DIR)
	@echo "All ISBP data removed."

################################################################################
# Development helpers
################################################################################
lint:
	@echo "Checking shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found"; exit 1; }
	@shellcheck $(PROJECT_DIR)/*.sh $(TOOLS_DIR)/*.sh $(EXAMPLES_DIR)/*.sh $(TESTS_DIR)/*.sh || true

format:
	@echo "Formatting shell scripts..."
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@shfmt -i 4 -w $(PROJECT_DIR)/*.sh $(TOOLS_DIR)/*.sh $(EXAMPLES_DIR)/*.sh $(TESTS_DIR)/*.sh || true

################################################################################
# Economic Simulation
################################################################################
SIM_SCRIPT := $(TOOLS_DIR)/constellation_sim.sh

sim:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users $(USERS) --stations $(STATIONS) --devs $(DEVS) --cms $(CMS) --paf $(PAF)

# Default simulation parameters
USERS ?= 500
STATIONS ?= 5
DEVS ?= 2
CMS ?= 1
PAF ?= 14

sim-small:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users 100 --stations 1 --devs 1 --cms 0 --multipass-pct 80

sim-medium:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users 500 --stations 5 --devs 2 --cms 1 --multipass-pct 80

sim-large:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users 2000 --stations 15 --devs 5 --cms 3 --multipass-pct 80

sim-json:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users $(USERS) --stations $(STATIONS) --devs $(DEVS) --cms $(CMS) --output json

sim-csv:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users $(USERS) --stations $(STATIONS) --devs $(DEVS) --cms $(CMS) --output csv

sim-html:
	@echo "Opening interactive simulator..."
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open $(PROJECT_DIR)/docs/simulator.html; \
	elif command -v open >/dev/null 2>&1; then \
		open $(PROJECT_DIR)/docs/simulator.html; \
	else \
		echo "Open in browser: file://$(PROJECT_DIR)/docs/simulator.html"; \
	fi

# Custom simulation with all parameters
# Usage: make sim-custom USERS=1000 STATIONS=10 DEVS=3 CMS=2 PAF=14 MPCT=75
MPCT ?= 80
sim-custom:
	@chmod +x $(SIM_SCRIPT)
	@bash $(SIM_SCRIPT) --users $(USERS) --stations $(STATIONS) --devs $(DEVS) --cms $(CMS) --paf $(PAF) --multipass-pct $(MPCT)
