#!/usr/bin/env bash
# ==========================================================
# ROCm + Ollama + Model Setup Script (with logging & progress)
# Target: Ubuntu 24.04.3 LTS + Kernel 6.14.0-35-generic
# GPU: AMD Radeon RX 7900 / PRO Series
# ==========================================================

set -e

LOGFILE="install.log"
exec > >(tee -a "$LOGFILE") 2>&1
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# --- Colors & Helpers ---
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }
info()  { echo -e "${GREEN}$(timestamp) [INFO]${RESET} $1"; }
warn()  { echo -e "${YELLOW}$(timestamp) [WARN]${RESET} $1"; }
error() { echo -e "${RED}$(timestamp) [ERROR]${RESET} $1"; }

# --- Spinner for long-running commands ---
spinner() {
  local pid=$1
  local delay=0.2
  local spinstr='|/-\'
  echo -n " "
  while ps -p $pid > /dev/null 2>&1; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  echo " "
}

# --- Progress bar (for Ollama model pulls) ---
progress_bar() {
  local progress=$1
  local total=$2
  local percent=$(( progress * 100 / total ))
  local filled=$(( percent / 2 ))
  local empty=$(( 50 - filled ))
  printf "\r["
  printf "%0.s#" $(seq 1 $filled)
  printf "%0.s-" $(seq 1 $empty)
  printf "] %d%%" "$percent"
}

info "===== ROCm + Ollama Installation Started at $START_TIME ====="

# ==========================================================
# 1. Update and install dependencies
# ==========================================================
info "Updating package lists..."
sudo apt update -y &
spinner $!

info "Installing dependencies..."
sudo apt install -y tmux asciinema ttyrec python3 python3-pip curl snapd jq bc gnupg htop lm-sensors wget &
spinner $!

info "Installing Python packages..."
python3 -m pip install --upgrade pip matplotlib pandas &
spinner $!

# ==========================================================
# 2. Install Ollama
# ==========================================================
info "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh &
spinner $!

# ==========================================================
# 3. ROCm utilities
# ==========================================================
info "Installing ROCm utilities..."
sudo snap install rocminfo || warn "rocminfo (snap) failed — continuing."
sudo apt install -y rocm-smi radeontop rocprofiler-compute || warn "Some ROCm utilities missing — continuing."

# ==========================================================
# 4. Verify OS and Kernel
# ==========================================================
info "Checking OS and kernel versions..."
OS_VERSION=$(lsb_release -ds)
KERNEL_VERSION=$(uname -r)
info "Detected OS: $OS_VERSION"
info "Detected Kernel: $KERNEL_VERSION"
echo "Expected OS: Ubuntu 24.04.3 LTS"
echo "Expected Kernel: 6.14.0-35-generic"

# ==========================================================
# 5. Add ROCm repositories
# ==========================================================
info "Adding ROCm and AMDGPU repositories..."
sudo mkdir -p /etc/apt/keyrings
wget -q https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
  gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

cat <<EOF | sudo tee /etc/apt/sources.list.d/amdgpu.list > /dev/null
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.4.4/ubuntu noble main
EOF

cat <<EOF | sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.4.4 noble main
EOF

sudo apt update -y &
spinner $!

# ==========================================================
# 6. DKMS / ROCm Install
# ==========================================================
info "Installing AMDGPU driver and ROCm stack..."
if ! sudo apt install -y amdgpu-dkms rocm; then
  warn "DKMS install failed — using fallback non-DKMS method."
  sudo apt install -y rocm amdgpu-install
  sudo amdgpu-install --usecase=rocm --no-dkms || warn "Fallback install encountered issues — check logs."
fi

# ==========================================================
# 7. Add user to render/video groups
# ==========================================================
info "Adding $USER to render and video groups..."
sudo usermod -a -G render,video "$USER"

# ==========================================================
# 8. Ollama model pulls with progress
# ==========================================================
info "Pulling Ollama models — this will take significant time."
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

TOTAL_MODELS=${#MODELS[@]}
count=0

for model in "${MODELS[@]}"; do
  count=$((count + 1))
  info "Pulling model ($count/$TOTAL_MODELS): $model"
  if ollama pull "$model"; then
    info "Completed: $model"
  else
    error "Failed to pull: $model"
  fi
done

# ==========================================================
# 9. Completion
# ==========================================================
END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
info "===== Installation Finished at $END_TIME ====="
echo ""
echo "=========================================================="
echo "✅  Installation complete."
echo "📄  Log file saved to: $LOGFILE"
echo ""
echo "Next Steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. After reboot, verify with:"
echo "       /opt/rocm/bin/rocminfo"
echo "       /opt/rocm/bin/rocm-smi"
echo ""
echo "Expected: GPU listed + ROCm runtime operational."
echo "=========================================================="
