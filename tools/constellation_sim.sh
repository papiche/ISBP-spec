#!/bin/bash
################################################################################
# Constellation Economic Simulator
# Simulates the economy of a UPlanet ẐEN constellation
#
# Based on ZEN.ECONOMY principles:
# - Weekly PAF payments (NODE + CAPTAIN)
# - 3x1/3 cooperative allocation
# - Progressive degradation phases
#
# Usage: ./constellation_sim.sh [options]
#
# Options:
#   --users N         Total users (default: 500)
#   --multipass-pct P Percentage of MULTIPASS users (default: 80)
#   --stations N      Number of stations (default: 5)
#   --devs N          Number of developers (default: 2)
#   --cms N           Number of community managers (default: 1)
#   --paf N           Weekly PAF amount in Ẑen (default: 14)
#   --multipass-fee N Weekly MULTIPASS fee (default: 1)
#   --zencard-fee N   Yearly ZEN Card fee (default: 50)
#   --dev-salary N    Monthly developer salary (default: 4340)
#   --cm-salary N     Monthly CM salary (default: 1360)
#   --cycles N        Number of 4-week cycles to simulate (default: 13)
#   --output FORMAT   Output format: text, json, csv (default: text)
#   --verbose         Show detailed week-by-week simulation
#
# License: AGPL-3.0
################################################################################

set -e

# Default configuration
TOTAL_USERS=500
MULTIPASS_PCT=80
NB_STATIONS=5
NB_DEVS=2
NB_CMS=1
PAF=14
MULTIPASS_FEE=1
ZENCARD_FEE=50
DEV_SALARY=4340
CM_SALARY=1360
NB_CYCLES=13
OUTPUT_FORMAT="text"
VERBOSE=0

# Constants
WEEKS_PER_CYCLE=4
TAX_THRESHOLD=42500
TAX_RATE_REDUCED=15
TAX_RATE_NORMAL=25
ALLOCATION_TREASURY=33.33
ALLOCATION_RND=33.33
ALLOCATION_ASSETS=33.34
FOREST_PRICE_PER_M2=2
MULTIPASS_CAPACITY=250
ZENCARD_CAPACITY=24

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# Parse arguments
################################################################################
while [[ $# -gt 0 ]]; do
    case $1 in
        --users) TOTAL_USERS="$2"; shift 2 ;;
        --multipass-pct) MULTIPASS_PCT="$2"; shift 2 ;;
        --stations) NB_STATIONS="$2"; shift 2 ;;
        --devs) NB_DEVS="$2"; shift 2 ;;
        --cms) NB_CMS="$2"; shift 2 ;;
        --paf) PAF="$2"; shift 2 ;;
        --multipass-fee) MULTIPASS_FEE="$2"; shift 2 ;;
        --zencard-fee) ZENCARD_FEE="$2"; shift 2 ;;
        --dev-salary) DEV_SALARY="$2"; shift 2 ;;
        --cm-salary) CM_SALARY="$2"; shift 2 ;;
        --cycles) NB_CYCLES="$2"; shift 2 ;;
        --output) OUTPUT_FORMAT="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --help|-h)
            grep "^#" "$0" | head -30 | tail -28 | cut -c3-
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

################################################################################
# Calculations
################################################################################
calculate() {
    echo "scale=2; $1" | bc -l
}

format_number() {
    local num="${1%.*}"
    echo "${num}"
}

format_currency() {
    local num=$(printf "%.2f" "$1" 2>/dev/null)
    echo "${num} Ẑ"
}

################################################################################
# Derived values
################################################################################
NB_MULTIPASS=$(calculate "${TOTAL_USERS} * ${MULTIPASS_PCT} / 100")
NB_MULTIPASS=${NB_MULTIPASS%.*}
NB_ZENCARD=$((TOTAL_USERS - NB_MULTIPASS))

# Capacity calculation
MAX_MULTIPASS=$((NB_STATIONS * MULTIPASS_CAPACITY))
MAX_ZENCARD=$((NB_STATIONS * ZENCARD_CAPACITY))
UTILIZATION_RATE=$(calculate "(${TOTAL_USERS} / (${MAX_MULTIPASS} * ${MULTIPASS_PCT} / 100 + ${MAX_ZENCARD} * (100 - ${MULTIPASS_PCT}) / 100)) * 100")

# Per cycle (4 weeks) calculations
REVENUE_MULTIPASS=$(calculate "${NB_MULTIPASS} * ${MULTIPASS_FEE} * ${WEEKS_PER_CYCLE}")
REVENUE_ZENCARD_YEARLY=$(calculate "${NB_ZENCARD} * ${ZENCARD_FEE}")
REVENUE_ZENCARD_CYCLE=$(calculate "${REVENUE_ZENCARD_YEARLY} / ${NB_CYCLES}")
REVENUE_TOTAL=$(calculate "${REVENUE_MULTIPASS} + ${REVENUE_ZENCARD_CYCLE}")

# TVA (20%)
TVA=$(calculate "${REVENUE_TOTAL} * 0.20")
REVENUE_HT=$(calculate "${REVENUE_TOTAL} - ${TVA}")

# Costs per cycle
COST_CAPTAIN=$(calculate "${NB_STATIONS} * ${PAF} * 3 * ${WEEKS_PER_CYCLE}")
COST_DEVS=$(calculate "${NB_DEVS} * ${DEV_SALARY}")
COST_CMS=$(calculate "${NB_CMS} * ${CM_SALARY}")
COST_RD=$(calculate "${COST_DEVS} + ${COST_CMS}")
COST_TOTAL=$(calculate "${COST_CAPTAIN} + ${COST_RD}")

# Results
GROSS_MARGIN=$(calculate "${REVENUE_HT} - ${COST_CAPTAIN}")
RESULT_BEFORE_TAX=$(calculate "${GROSS_MARGIN} - ${COST_RD}")

# Tax calculation
if (( $(echo "${RESULT_BEFORE_TAX} > 0" | bc -l) )); then
    if (( $(echo "${RESULT_BEFORE_TAX} <= ${TAX_THRESHOLD}" | bc -l) )); then
        TAX_RATE=${TAX_RATE_REDUCED}
    else
        TAX_RATE=${TAX_RATE_NORMAL}
    fi
    TAX_AMOUNT=$(calculate "${RESULT_BEFORE_TAX} * ${TAX_RATE} / 100")
else
    TAX_RATE=0
    TAX_AMOUNT=0
fi

NET_RESULT=$(calculate "${RESULT_BEFORE_TAX} - ${TAX_AMOUNT}")

# 3x1/3 allocation (if positive)
if (( $(echo "${NET_RESULT} > 0" | bc -l) )); then
    ALLOC_TREASURY=$(calculate "${NET_RESULT} * ${ALLOCATION_TREASURY} / 100")
    ALLOC_RND=$(calculate "${NET_RESULT} * ${ALLOCATION_RND} / 100")
    ALLOC_ASSETS=$(calculate "${NET_RESULT} * ${ALLOCATION_ASSETS} / 100")
    FOREST_M2=$(calculate "${ALLOC_ASSETS} / ${FOREST_PRICE_PER_M2}")
else
    ALLOC_TREASURY=0
    ALLOC_RND=0
    ALLOC_ASSETS=0
    FOREST_M2=0
fi

# KPIs
GROSS_MARGIN_PCT=$(calculate "(${GROSS_MARGIN} / ${REVENUE_HT}) * 100")
AVG_REVENUE_PER_USER=$(calculate "${REVENUE_HT} / ${TOTAL_USERS}")
BREAK_EVEN=$(calculate "${COST_TOTAL} / (${MULTIPASS_FEE} * ${WEEKS_PER_CYCLE})")
JOBS_CREATED=$((NB_DEVS + NB_CMS))

# Yearly projections
YEARLY_REVENUE=$(calculate "${REVENUE_TOTAL} * ${NB_CYCLES}")
YEARLY_NET=$(calculate "${NET_RESULT} * ${NB_CYCLES}")
YEARLY_FOREST=$(calculate "${FOREST_M2} * ${NB_CYCLES}")

################################################################################
# Output functions
################################################################################
output_text() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       🏛️ ISBP Constellation Economic Simulator                     ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📊 CONFIGURATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  %-25s %s\n" "Total users:" "${TOTAL_USERS}"
    printf "  %-25s %s (%s%%)\n" "MULTIPASS:" "${NB_MULTIPASS}" "${MULTIPASS_PCT}"
    printf "  %-25s %s (%s%%)\n" "ZEN Cards:" "${NB_ZENCARD}" "$((100 - MULTIPASS_PCT))"
    printf "  %-25s %s\n" "Stations:" "${NB_STATIONS}"
    printf "  %-25s %s\n" "Developers:" "${NB_DEVS}"
    printf "  %-25s %s\n" "Community Managers:" "${NB_CMS}"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📈 CAPACITY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  %-25s %s\n" "Max MULTIPASS:" "${MAX_MULTIPASS}"
    printf "  %-25s %s\n" "Max ZEN Cards:" "${MAX_ZENCARD}"
    
    if (( $(echo "${UTILIZATION_RATE} > 100" | bc -l) )); then
        echo -e "  Utilization rate:         ${RED}${UTILIZATION_RATE}% ⚠️ OVERCAPACITY${NC}"
    elif (( $(echo "${UTILIZATION_RATE} > 80" | bc -l) )); then
        echo -e "  Utilization rate:         ${YELLOW}${UTILIZATION_RATE}%${NC}"
    else
        echo -e "  Utilization rate:         ${GREEN}${UTILIZATION_RATE}%${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}💰 REVENUES (per ${WEEKS_PER_CYCLE}-week cycle)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  %-25s ${GREEN}%s${NC}\n" "MULTIPASS fees:" "$(format_currency ${REVENUE_MULTIPASS})"
    printf "  %-25s ${GREEN}%s${NC}\n" "ZEN Card fees:" "$(format_currency ${REVENUE_ZENCARD_CYCLE})"
    printf "  %-25s ${GREEN}%s${NC}\n" "Total (TTC):" "$(format_currency ${REVENUE_TOTAL})"
    printf "  %-25s ${RED}-%s${NC}\n" "TVA (20%):" "$(format_currency ${TVA})"
    printf "  %-25s ${GREEN}%s${NC}\n" "Total (HT):" "$(format_currency ${REVENUE_HT})"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}💸 COSTS (per ${WEEKS_PER_CYCLE}-week cycle)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  %-25s ${RED}%s${NC}\n" "Captain wages (3×PAF):" "$(format_currency ${COST_CAPTAIN})"
    printf "  %-25s ${RED}%s${NC}\n" "Developer salaries:" "$(format_currency ${COST_DEVS})"
    printf "  %-25s ${RED}%s${NC}\n" "CM salaries:" "$(format_currency ${COST_CMS})"
    printf "  %-25s ${RED}%s${NC}\n" "Total costs:" "$(format_currency ${COST_TOTAL})"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📊 RESULTS (per ${WEEKS_PER_CYCLE}-week cycle)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if (( $(echo "${GROSS_MARGIN} >= 0" | bc -l) )); then
        printf "  %-25s ${GREEN}%s${NC}\n" "Gross margin:" "$(format_currency ${GROSS_MARGIN})"
    else
        printf "  %-25s ${RED}%s${NC}\n" "Gross margin:" "$(format_currency ${GROSS_MARGIN})"
    fi
    
    if (( $(echo "${RESULT_BEFORE_TAX} >= 0" | bc -l) )); then
        printf "  %-25s ${GREEN}%s${NC}\n" "Result before tax:" "$(format_currency ${RESULT_BEFORE_TAX})"
    else
        printf "  %-25s ${RED}%s${NC}\n" "Result before tax:" "$(format_currency ${RESULT_BEFORE_TAX})"
    fi
    
    printf "  %-25s ${RED}-%s${NC} (%s%%)\n" "Corporate tax:" "$(format_currency ${TAX_AMOUNT})" "${TAX_RATE}"
    
    if (( $(echo "${NET_RESULT} >= 0" | bc -l) )); then
        echo -e "  ${BOLD}Net result:${NC}               ${GREEN}${BOLD}$(format_currency ${NET_RESULT})${NC}"
    else
        echo -e "  ${BOLD}Net result:${NC}               ${RED}${BOLD}$(format_currency ${NET_RESULT})${NC}"
    fi
    echo ""
    
    if (( $(echo "${NET_RESULT} > 0" | bc -l) )); then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}🌱 3×1/3 COOPERATIVE ALLOCATION${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        printf "  %-25s ${BLUE}%s${NC}\n" "🏦 Treasury (CASH):" "$(format_currency ${ALLOC_TREASURY})"
        printf "  %-25s ${YELLOW}%s${NC}\n" "🔬 R&D:" "$(format_currency ${ALLOC_RND})"
        printf "  %-25s ${GREEN}%s${NC}\n" "🌳 Assets:" "$(format_currency ${ALLOC_ASSETS})"
        echo ""
        echo -e "  🌲 ${GREEN}Forest acquisition: $(format_number ${FOREST_M2%.*}) m²/cycle${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📈 KPIs${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if (( $(echo "${GROSS_MARGIN_PCT} >= 50" | bc -l) )); then
        printf "  %-25s ${GREEN}%s%%${NC}\n" "Gross margin rate:" "${GROSS_MARGIN_PCT%.*}"
    elif (( $(echo "${GROSS_MARGIN_PCT} >= 0" | bc -l) )); then
        printf "  %-25s ${YELLOW}%s%%${NC}\n" "Gross margin rate:" "${GROSS_MARGIN_PCT%.*}"
    else
        printf "  %-25s ${RED}%s%%${NC}\n" "Gross margin rate:" "${GROSS_MARGIN_PCT%.*}"
    fi
    
    printf "  %-25s %s\n" "Break-even point:" "${BREAK_EVEN%.*} MULTIPASS users"
    printf "  %-25s %s\n" "Avg revenue/user:" "$(format_currency ${AVG_REVENUE_PER_USER})"
    printf "  %-25s %s\n" "Jobs created:" "${JOBS_CREATED}"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📅 YEARLY PROJECTION (${NB_CYCLES} cycles)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "  %-25s ${GREEN}%s${NC}\n" "Annual revenue:" "$(format_currency ${YEARLY_REVENUE})"
    
    if (( $(echo "${YEARLY_NET} >= 0" | bc -l) )); then
        printf "  %-25s ${GREEN}%s${NC}\n" "Annual net result:" "$(format_currency ${YEARLY_NET})"
    else
        printf "  %-25s ${RED}%s${NC}\n" "Annual net result:" "$(format_currency ${YEARLY_NET})"
    fi
    
    printf "  %-25s ${GREEN}%s m²${NC}\n" "Forest acquisition:" "$(format_number ${YEARLY_FOREST%.*})"
    echo ""
    
    # Viability assessment
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}🎯 VIABILITY ASSESSMENT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if (( $(echo "${NET_RESULT} > 0" | bc -l) )) && (( $(echo "${UTILIZATION_RATE} <= 100" | bc -l) )); then
        echo -e "  ${GREEN}✅ VIABLE${NC} - Positive net result within capacity"
    elif (( $(echo "${NET_RESULT} > 0" | bc -l) )); then
        echo -e "  ${YELLOW}⚠️ PROFITABLE BUT OVERCAPACITY${NC} - Add more stations"
    elif (( $(echo "${RESULT_BEFORE_TAX} > 0" | bc -l) )); then
        echo -e "  ${YELLOW}⚠️ MARGINALLY VIABLE${NC} - Covers costs before tax"
    elif (( $(echo "${GROSS_MARGIN} > 0" | bc -l) )); then
        echo -e "  ${YELLOW}⚠️ OPERATIONAL${NC} - Reduce R&D costs or increase users"
    else
        echo -e "  ${RED}❌ NOT VIABLE${NC} - Insufficient revenue to cover operations"
    fi
    echo ""
}

output_json() {
    cat << EOF
{
    "configuration": {
        "total_users": ${TOTAL_USERS},
        "multipass_users": ${NB_MULTIPASS},
        "zencard_users": ${NB_ZENCARD},
        "multipass_pct": ${MULTIPASS_PCT},
        "stations": ${NB_STATIONS},
        "developers": ${NB_DEVS},
        "community_managers": ${NB_CMS},
        "paf": ${PAF},
        "multipass_fee": ${MULTIPASS_FEE},
        "zencard_fee": ${ZENCARD_FEE}
    },
    "capacity": {
        "max_multipass": ${MAX_MULTIPASS},
        "max_zencard": ${MAX_ZENCARD},
        "utilization_rate": ${UTILIZATION_RATE}
    },
    "revenues_per_cycle": {
        "multipass": ${REVENUE_MULTIPASS},
        "zencard": ${REVENUE_ZENCARD_CYCLE},
        "total_ttc": ${REVENUE_TOTAL},
        "tva": ${TVA},
        "total_ht": ${REVENUE_HT}
    },
    "costs_per_cycle": {
        "captain_wages": ${COST_CAPTAIN},
        "developer_salaries": ${COST_DEVS},
        "cm_salaries": ${COST_CMS},
        "total": ${COST_TOTAL}
    },
    "results_per_cycle": {
        "gross_margin": ${GROSS_MARGIN},
        "result_before_tax": ${RESULT_BEFORE_TAX},
        "tax_rate": ${TAX_RATE},
        "tax_amount": ${TAX_AMOUNT},
        "net_result": ${NET_RESULT}
    },
    "allocation": {
        "treasury": ${ALLOC_TREASURY},
        "rnd": ${ALLOC_RND},
        "assets": ${ALLOC_ASSETS},
        "forest_m2": ${FOREST_M2}
    },
    "kpis": {
        "gross_margin_pct": ${GROSS_MARGIN_PCT},
        "break_even_users": ${BREAK_EVEN%.*},
        "avg_revenue_per_user": ${AVG_REVENUE_PER_USER},
        "jobs_created": ${JOBS_CREATED}
    },
    "yearly_projection": {
        "cycles": ${NB_CYCLES},
        "revenue": ${YEARLY_REVENUE},
        "net_result": ${YEARLY_NET},
        "forest_m2": ${YEARLY_FOREST}
    }
}
EOF
}

output_csv() {
    echo "metric,value,unit"
    echo "total_users,${TOTAL_USERS},users"
    echo "multipass_users,${NB_MULTIPASS},users"
    echo "zencard_users,${NB_ZENCARD},users"
    echo "stations,${NB_STATIONS},nodes"
    echo "utilization_rate,${UTILIZATION_RATE},%"
    echo "revenue_ht,${REVENUE_HT},Ẑen"
    echo "total_costs,${COST_TOTAL},Ẑen"
    echo "gross_margin,${GROSS_MARGIN},Ẑen"
    echo "net_result,${NET_RESULT},Ẑen"
    echo "gross_margin_pct,${GROSS_MARGIN_PCT},%"
    echo "break_even,${BREAK_EVEN%.*},users"
    echo "forest_m2_cycle,${FOREST_M2},m²"
    echo "yearly_net,${YEARLY_NET},Ẑen"
    echo "yearly_forest,${YEARLY_FOREST},m²"
}

################################################################################
# Main
################################################################################
case "${OUTPUT_FORMAT}" in
    json) output_json ;;
    csv) output_csv ;;
    *) output_text ;;
esac
