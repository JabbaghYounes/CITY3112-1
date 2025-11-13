#!/usr/bin/env bash
# ==========================================================
# fix.sh — Install missing dependencies found by check.sh
# ==========================================================

set -e

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

info()  { echo -e "${GREEN}[INFO]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }
step()  { echo -e "${BLUE}[STEP]${RESET} $1"; }

echo "=========================================================="
echo "  Dependency Fix Script"
echo "=========================================================="
echo ""

# ==========================================================
# 1. Install Python packages
# ==========================================================
step "1. Installing Python packages (matplotlib, pandas)..."
if python3 -m pip install --user matplotlib pandas; then
    info "Python packages installed successfully"
else
    error "Failed to install Python packages"
    exit 1
fi
echo ""

# ==========================================================
# 2. Add user to render/video groups
# ==========================================================
step "2. Adding user to render and video groups..."
if sudo usermod -a -G render,video "$USER"; then
    info "User added to render and video groups"
    warn "You may need to log out and log back in for group changes to take effect"
else
    error "Failed to add user to groups"
fi
echo ""

# ==========================================================
# 3. Pull Ollama models
# ==========================================================
if command -v ollama &>/dev/null; then
    step "3. Pulling Ollama models (this will take a long time)..."
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
    
    TOTAL=${#MODELS[@]}
    count=0
    
    for model in "${MODELS[@]}"; do
        count=$((count + 1))
        info "Pulling model ($count/$TOTAL): $model"
        if ollama pull "$model"; then
            info "✓ Completed: $model"
        else
            error "✗ Failed to pull: $model"
        fi
    done
    echo ""
else
    warn "Ollama not found - skipping model pulls"
    echo ""
fi

# ==========================================================
# 4. Check ROCm installation
# ==========================================================
step "4. Checking ROCm installation..."

if [ -f "/opt/rocm/bin/rocminfo" ]; then
    info "ROCm appears to be installed in /opt/rocm"
    
    # Check if rocm-smi exists
    if [ -f "/opt/rocm/bin/rocm-smi" ]; then
        info "rocm-smi found at /opt/rocm/bin/rocm-smi"
        warn "You may want to add /opt/rocm/bin to your PATH"
        echo "  Add this to your ~/.bashrc:"
        echo "  export PATH=\$PATH:/opt/rocm/bin"
    else
        warn "rocm-smi not found. ROCm may need to be reinstalled."
        echo "  Run: bash scripts/setup.sh (ROCm section)"
    fi
else
    warn "ROCm not found in /opt/rocm"
    echo "  To install ROCm, run: bash scripts/setup.sh"
    echo "  Note: This requires sudo and may require a reboot"
fi
echo ""

# ==========================================================
# Summary
# ==========================================================
echo "=========================================================="
echo "  Fix Summary"
echo "=========================================================="
echo ""
info "✓ Python packages installed"
info "✓ User groups updated (log out/in to apply)"
if command -v ollama &>/dev/null; then
    info "✓ Ollama models pulled"
fi
echo ""
echo "Next steps:"
echo "  1. Log out and log back in (for group changes)"
echo "  2. Run ./check.sh again to verify"
echo "  3. If ROCm is missing, run: bash scripts/setup.sh"
echo ""

