#!/usr/bin/env bash
# ==========================================================
# check.sh — Post-setup dependency verification script
# Verifies all dependencies installed by setup.sh
# ==========================================================

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

PASSED=0
FAILED=0
WARNINGS=0

check_cmd() {
    local cmd=$1
    local name=$2
    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${RESET} $name"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${RESET} $name (not found)"
        ((FAILED++))
        return 1
    fi
}

check_pkg() {
    local pkg=$1
    if dpkg -l | grep -q "^ii.*$pkg "; then
        echo -e "${GREEN}✓${RESET} $pkg (package installed)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${RESET} $pkg (package not found)"
        ((FAILED++))
        return 1
    fi
}

check_python_pkg() {
    local pkg=$1
    if python3 -c "import $pkg" 2>/dev/null; then
        echo -e "${GREEN}✓${RESET} $pkg (Python package)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${RESET} $pkg (Python package not found)"
        ((FAILED++))
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}ℹ${RESET} $1"
}

echo "=========================================================="
echo "  Dependency Check Script"
echo "=========================================================="
echo ""

# ==========================================================
# 1. System Dependencies
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "System Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_cmd "jq" "jq (JSON processor)"
check_cmd "bc" "bc (calculator)"
check_cmd "gpg" "gnupg (GPG)"
check_cmd "htop" "htop (system monitor)"
check_cmd "sensors" "lm-sensors (sensor data)"
check_cmd "wget" "wget (downloader)"
check_cmd "tmux" "tmux (terminal multiplexer)"
check_cmd "asciinema" "asciinema (recorder)"
check_cmd "ttyrec" "ttyrec (terminal recorder)"
check_cmd "python3" "Python 3"
check_cmd "pip3" "pip3 (Python package manager)"
check_cmd "curl" "curl (HTTP client)"
check_cmd "snap" "snapd (snap package manager)"

echo ""

# ==========================================================
# 2. Python Packages
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Python Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_python_pkg "matplotlib"
check_python_pkg "pandas"

echo ""

# ==========================================================
# 3. Ollama
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ollama Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if check_cmd "ollama" "Ollama CLI"; then
    OLLAMA_VERSION=$(ollama --version 2>/dev/null || echo "unknown")
    info "Ollama version: $OLLAMA_VERSION"
    
    # Check if Ollama service is running
    if pgrep -x ollama > /dev/null; then
        echo -e "${GREEN}✓${RESET} Ollama service is running"
        ((PASSED++))
    else
        warn "Ollama service is not running (start with: ollama serve)"
    fi
else
    warn "Ollama not installed - cannot check models"
fi

echo ""

# ==========================================================
# 4. Ollama Models
# ==========================================================
if command -v ollama &>/dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ollama Models"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    MODELS=(
        "gpt-oss:20b"
        "gpt-oss:120b"
        "deepseek-r1:1.5b"
        "deepseek-r1:7b"
        "deepseek-r1:8b"
        "deepseek-r1:14b"
        "deepseek-r1:32b"
        "deepseek-r1:70b"
        "deepseek-r1:671b"
        "kimi-k2:1026b"
    )
    
    if ollama list &>/dev/null; then
        INSTALLED_MODELS=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | sort)
        for model in "${MODELS[@]}"; do
            if echo "$INSTALLED_MODELS" | grep -q "^${model}$"; then
                echo -e "${GREEN}✓${RESET} $model"
                ((PASSED++))
            else
                echo -e "${RED}✗${RESET} $model (not installed)"
                ((FAILED++))
            fi
        done
    else
        warn "Cannot list Ollama models (service may not be running)"
        for model in "${MODELS[@]}"; do
            echo -e "${YELLOW}?${RESET} $model (cannot verify)"
        done
    fi
    echo ""
fi

# ==========================================================
# 5. ROCm Utilities
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ROCm Utilities"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for rocminfo (can be in /opt/rocm/bin or snap)
if [ -f "/opt/rocm/bin/rocminfo" ] || command -v rocminfo &>/dev/null; then
    echo -e "${GREEN}✓${RESET} rocminfo"
    ((PASSED++))
    if [ -f "/opt/rocm/bin/rocminfo" ]; then
        info "rocminfo location: /opt/rocm/bin/rocminfo"
    fi
else
    echo -e "${RED}✗${RESET} rocminfo (not found)"
    ((FAILED++))
fi

# Check for rocm-smi
if check_cmd "rocm-smi" "rocm-smi"; then
    if rocm-smi &>/dev/null; then
        info "rocm-smi is functional"
        # Try to get GPU info
        if rocm-smi --showid &>/dev/null; then
            GPU_COUNT=$(rocm-smi --showid 2>/dev/null | grep -c "Card series" || echo "0")
            if [ "$GPU_COUNT" -gt 0 ]; then
                info "Detected $GPU_COUNT GPU(s)"
            fi
        fi
    else
        warn "rocm-smi found but may not be functional"
    fi
fi

# Check for other ROCm utilities
if command -v radeontop &>/dev/null; then
    echo -e "${GREEN}✓${RESET} radeontop"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${RESET} radeontop (optional, not found)"
    ((WARNINGS++))
fi

if command -v rocprofiler-compute &>/dev/null || [ -f "/opt/rocm/bin/rocprofiler-compute" ]; then
    echo -e "${GREEN}✓${RESET} rocprofiler-compute"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${RESET} rocprofiler-compute (optional, not found)"
    ((WARNINGS++))
fi

echo ""

# ==========================================================
# 6. ROCm Runtime Check
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ROCm Runtime & GPU"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "/opt/rocm/bin/rocminfo" ]; then
    if /opt/rocm/bin/rocminfo &>/dev/null; then
        echo -e "${GREEN}✓${RESET} ROCm runtime is accessible"
        ((PASSED++))
        
        # Try to get GPU information
        ROCM_INFO=$(/opt/rocm/bin/rocminfo 2>/dev/null | head -20)
        if echo "$ROCM_INFO" | grep -qi "gpu\|device\|card"; then
            info "GPU detected in ROCm info"
        else
            warn "No GPU detected in ROCm info (may need reboot or GPU not supported)"
        fi
    else
        echo -e "${RED}✗${RESET} ROCm runtime not functional"
        ((FAILED++))
        warn "May need to reboot system after ROCm installation"
    fi
else
    echo -e "${RED}✗${RESET} ROCm not installed or not in expected location"
    ((FAILED++))
    warn "Run setup.sh to install ROCm"
fi

# Check user groups
if groups | grep -q "render\|video"; then
    echo -e "${GREEN}✓${RESET} User in render/video groups"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${RESET} User not in render/video groups (may need to log out/in)"
    ((WARNINGS++))
    info "Run: sudo usermod -a -G render,video $USER"
fi

echo ""

# ==========================================================
# 7. Summary
# ==========================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Passed:${RESET} $PASSED"
echo -e "${RED}Failed:${RESET} $FAILED"
echo -e "${YELLOW}Warnings:${RESET} $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All critical dependencies are installed!${RESET}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ Some optional components are missing (see warnings above)${RESET}"
    fi
    exit 0
else
    echo -e "${RED}❌ Some dependencies are missing. Please run setup.sh to install them.${RESET}"
    exit 1
fi

