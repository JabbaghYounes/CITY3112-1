#!/usr/bin/env bash
# ==========================================================
# Get all Dependencies
# ==========================================================

set -e  # Stop on first error

LOGFILE="install.log"
exec > >(tee -a "$LOGFILE") 2>&1
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# --- Color + timestamp helpers ---
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
timestamp() { date +"[%Y-%m-%d %H:%M:%S]"; }
info()  { echo -e "${GREEN}$(timestamp) [INFO]${RESET} $1"; }
warn()  { echo -e "${YELLOW}$(timestamp) [WARN]${RESET} $1"; }
error() { echo -e "${RED}$(timestamp) [ERROR]${RESET} $1"; }

info "===== ROCm + Ollama Installation Started at $START_TIME ====="

# ==========================================================
# 1. System update and dependency installation
# ==========================================================
info "Updating package lists..."
sudo apt update -y

info "Installing dependencies..."
sudo apt install -y tmux asciinema ttyrec python3 python3-pip curl snapd

info "Installing Python packages..."
pip install --upgrade pip
pip install matplotlib pandas

# ==========================================================
# 2. Install Ollama
# ==========================================================
info "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# ==========================================================
# 3. Install ROCm utilities
# ==========================================================
info "Installing ROCm utilities..."
sudo snap install rocminfo || warn "rocminfo (snap) failed — continuing."
sudo apt install -y rocm-smi radeontop rocprofiler-compute || warn "Some ROCm utilities not found — continuing."

# ==========================================================
# 4. Verify OS and Kernel
# ==========================================================
info "Verifying OS and Kernel versions..."
OS_VERSION=$(lsb_release -ds)
KERNEL_VERSION=$(uname -r)
info "Detected OS: $OS_VERSION"
info "Detected Kernel: $KERNEL_VERSION"
echo "Expected OS: Ubuntu 24.04.3 LTS"
echo "Expected Kernel: 6.14.0-35-generic"

# ==========================================================
# 5. Add ROCm & AMDGPU repositories
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

sudo apt update -y

# ==========================================================
# 6. Attempt DKMS install
# ==========================================================
info "Installing AMDGPU driver and ROCm stack..."
if ! sudo apt install -y amdgpu-dkms rocm; then
  warn "DKMS install failed — using fallback non-DKMS method."
  sudo apt install -y rocm amdgpu-install
  sudo amdgpu-install --usecase=rocm --no-dkms || warn "Fallback install encountered issues — check logs."
fi

# ==========================================================
# 7. Add user to video/render groups
# ==========================================================
info "Adding $USER to render and video groups..."
sudo usermod -a -G render,video "$USER"

# ==========================================================
# 8. Ollama model pulls
# ==========================================================
info "Pulling Ollama models — this may take significant time."
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

for model in "${MODELS[@]}"; do
  info "Pulling model: $model"
  ollama pull "$model" || warn "Failed to pull $model — continuing."
done

# ==========================================================
# 9. Completion + Next Steps
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
echo "  2. After reboot, verify:"
echo "       /opt/rocm/bin/rocminfo"
echo "       /opt/rocm/bin/rocm-smi"
echo ""
echo "Expected results: GPU listed, ROCm runtime operational."
echo "=========================================================="
