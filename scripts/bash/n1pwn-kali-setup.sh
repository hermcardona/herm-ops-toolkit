#!/usr/bin/env bash
# N1PWN Kali Linux Customization Script
# Tested on Kali 2024+/Debian 12 base.

set -euo pipefail

########################################
# 0. Pre-flight
########################################

if [[ $EUID -ne 0 ]]; then
  echo "[!] Please run as root, e.g.: sudo $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-kali}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

if [[ ! -d "$TARGET_HOME" ]]; then
  echo "[!] Could not determine home for user '$TARGET_USER'."
  echo "    Edit TARGET_USER at the top of the script and re-run."
  exit 1
fi

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }

log "N1PWN Kali Customization Script starting..."
log "Target user : $TARGET_USER"
log "Target home : $TARGET_HOME"

########################################
# 1. Base system update & essentials
########################################

log "Updating base system and installing core packages..."

apt update
apt -y full-upgrade

# Core CLI & QoL
apt -y install \
  git curl wget \
  build-essential \
  htop neofetch tmux \
  zip unzip xclip \
  fonts-firacode \
  python3-pip python3-venv pipx \
  net-tools dnsutils iperf3 \
  jq tree rlwrap

# AD / ADCS tools from Kali repos
apt -y install bloodyad certipy-ad netexec evil-winrm seclists || \
  warn "Some offensive tools failed to install. Check package names and rerun if needed."

########################################
# 2. Browser + editor repos & installs
########################################

log "Configuring repositories for Chrome, Edge, VS Code, and Sublime Text..."

mkdir -p /etc/apt/keyrings

# --- Google Chrome ---
if ! command -v google-chrome >/dev/null 2>&1; then
  log "Adding Google Chrome repository..."
  wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor > /etc/apt/keyrings/google-linux.gpg

  cat >/etc/apt/sources.list.d/google-chrome.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/google-linux.gpg] http://dl.google.com/linux/chrome/deb/ stable main
EOF
else
  log "Google Chrome already present, skipping repo add."
fi

# --- Microsoft (Edge + VS Code) ---
if [[ ! -f /etc/apt/keyrings/microsoft.gpg ]]; then
  log "Adding Microsoft repository key..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /etc/apt/keyrings/microsoft.gpg
fi

cat >/etc/apt/sources.list.d/microsoft-edge.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main
EOF

cat >/etc/apt/sources.list.d/vscode.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

# --- Sublime Text ---
if [[ ! -f /etc/apt/keyrings/sublimehq-pub.asc ]]; then
  log "Adding Sublime Text repository..."
  wget -qO- https://download.sublimetext.com/sublimehq-pub.gpg \
    | tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
fi

cat >/etc/apt/sources.list.d/sublime-text.sources <<'EOF'
Types: deb
URIs: https://download.sublimetext.com/
Suites: apt/stable/
Signed-By: /etc/apt/keyrings/sublimehq-pub.asc
EOF

# --- Dropbox ---
log "Adding Dropbox repository..."
wget -qO- https://linux.dropbox.com/fedora/rpm-public-key.asc \
  | gpg --dearmor > /etc/apt/keyrings/dropbox.gpg

cat >/etc/apt/sources.list.d/dropbox.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/dropbox.gpg] http://linux.dropbox.com/debian bookworm main
EOF

log "Updating package lists after adding external repos..."
apt update

log "Installing Chrome, Edge, VS Code, Sublime, and Dropbox..."
apt -y install \
  google-chrome-stable \
  microsoft-edge-stable \
  code \
  sublime-text \
  dropbox || warn "Some GUI apps failed to install. Check error output."

########################################
# 3. Shell: zsh + oh-my-zsh for $TARGET_USER
########################################

log "Installing zsh & setting it as default shell for $TARGET_USER..."

apt -y install zsh

if ! grep -q "^${TARGET_USER}:" /etc/passwd; then
  warn "User $TARGET_USER not found in /etc/passwd for chsh. Skipping default shell change."
else
  chsh -s /usr/bin/zsh "$TARGET_USER" || warn "Could not change shell for $TARGET_USER."
fi

# Install oh-my-zsh for the non-root user
if [[ ! -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
  log "Installing oh-my-zsh for $TARGET_USER..."
  su - "$TARGET_USER" -c '
    export RUNZSH=no CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ' || warn "oh-my-zsh installation failed for $TARGET_USER."
else
  log "oh-my-zsh already present. Skipping installation."
fi

# Drop a tuned .zshrc if none exists
ZSHRC="${TARGET_HOME}/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
  log "Creating starter .zshrc for $TARGET_USER..."
  cat >"$ZSHRC" <<'EOF'
# N1PWN base .zshrc

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

plugins=(
  git
  docker
  pip
  python
  z
  history-substring-search
)

source $ZSH/oh-my-zsh.sh

# FiraCode-friendly settings
export TERM=xterm-256color

# Aliases - Herm style
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias k='kubectl'
alias cls='clear'

# Recon helpers
alias nmap-fast='nmap -T4 -Pn'
alias nmap-full='nmap -T4 -p- -Pn'
alias ffufw='ffuf -w /usr/share/seclists/Discovery/Web-Content/common.txt'
alias ferox='feroxbuster -u'

# AD / Windows helpers
alias nxc='netexec'
alias evil='evil-winrm'
alias certipy='certipy-ad'
EOF

  chown "$TARGET_USER:$TARGET_USER" "$ZSHRC"
fi

########################################
# 4. Offensive tooling: pyWhisker & DS_Walk
########################################

log "Installing pyWhisker via pipx for $TARGET_USER..."
su - "$TARGET_USER" -c '
  pipx ensurepath
  pipx install git+https://github.com/ShutdownRepo/pywhisker.git
' || warn "pyWhisker install failed. Check pipx output."

log "Cloning DS_Walk into /opt/ds_walk..."
if [[ ! -d /opt/ds_walk ]]; then
  git clone https://github.com/Keramas/DS_Walk.git /opt/ds_walk
  chown -R "$TARGET_USER:$TARGET_USER" /opt/ds_walk
fi

if [[ ! -L /usr/local/bin/ds_walk ]]; then
  ln -s /opt/ds_walk/ds_walk.py /usr/local/bin/ds_walk || warn "Could not symlink ds_walk."
fi

########################################
# 5. Discover (Lee Baird) – user-level install in $HOME
########################################

log "Cloning Discover into ${TARGET_USER}'s home and running update.sh..."

DISCOVER_DIR="${TARGET_HOME}/tools/discover"
DISCOVER_PARENT="$(dirname "$DISCOVER_DIR")"

# Create ~/tools if needed
mkdir -p "$DISCOVER_PARENT"
chown "$TARGET_USER:$TARGET_USER" "$DISCOVER_PARENT"

if [[ ! -d "$DISCOVER_DIR" ]]; then
  log "Cloning Discover into $DISCOVER_DIR..."
  # Clone as the target user so everything is owned correctly
  su - "$TARGET_USER" -c "
    mkdir -p \"$DISCOVER_PARENT\" &&
    cd \"$DISCOVER_PARENT\" &&
    git clone https://github.com/leebaird/discover.git discover
  " || warn "Failed to clone Discover into $DISCOVER_DIR."
else
  log "Discover already present at $DISCOVER_DIR. Skipping clone."
fi

# Run update.sh and patch hardcoded /opt/discover paths
log "Patching Discover to run from \$HOME and running update.sh as $TARGET_USER..."

su - "$TARGET_USER" -c '
  DISCOVER_DIR="$HOME/tools/discover"
  if [ ! -d "$DISCOVER_DIR" ]; then
    echo "[!] Discover directory not found at $DISCOVER_DIR"
    exit 0
  fi

  cd "$DISCOVER_DIR"

  # Make scripts executable
  chmod +x ./*.sh 2>/dev/null || true

  # Patch any hardcoded /opt/discover paths to the actual home-based path
  for f in ./*.sh; do
    [ -f "$f" ] || continue
    sed -i "s#/opt/discover#$DISCOVER_DIR#g" "$f" 2>/dev/null || true
  done

  # Run Discover's update script
  ./update.sh || echo "[!] discover/update.sh encountered errors. Review output."

########################################
# 6. SSH service – key-only, hardened
########################################

log "Installing and hardening OpenSSH server..."

apt -y install openssh-server

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup once
if [[ ! -f "${SSHD_CONFIG}.n1pwn.bak" ]]; then
  cp "$SSHD_CONFIG" "${SSHD_CONFIG}.n1pwn.bak"
fi

# Disable password auth & root login
sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^\s*#\?\s*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^\s*#\?\s*UsePAM.*/UsePAM yes/' "$SSHD_CONFIG"
sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"

systemctl enable ssh
systemctl restart ssh

# Make sure user has ~/.ssh with sane perms
log "Ensuring $TARGET_USER has ~/.ssh with correct permissions..."
su - "$TARGET_USER" -c '
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
'

log "SSH is now configured for key-only auth. Add your public keys to:"
echo "  ${TARGET_HOME}/.ssh/authorized_keys"

########################################
# 7. Light performance / sysctl tuning
########################################

log "Applying light sysctl tuning for desktop / lab usage..."

SYSCTL_FILE="/etc/sysctl.d/99-n1pwn.conf"

cat >"$SYSCTL_FILE" <<'EOF'
# N1PWN Kali tuning

# Reduce swapping
vm.swappiness = 10

# Increase file watches (nice for VS Code, etc.)
fs.inotify.max_user_watches = 524288

# Increase open files (helps heavy tooling)
fs.file-max = 1000000

# Slightly shorter FIN timeout
net.ipv4.tcp_fin_timeout = 15
EOF

sysctl --system >/dev/null 2>&1 || warn "sysctl reload had warnings; check manually."

########################################
# 8. Final status
########################################

log "N1PWN Kali customization complete."

echo
echo "Next steps for you, $TARGET_USER:"
echo "  1) Log out and back in so zsh/oh-my-zsh and pipx PATH take effect."
echo "  2) Drop your SSH pubkey into: ${TARGET_HOME}/.ssh/authorized_keys"
echo "  3) Test SSH from another box: ssh -i <key> ${TARGET_USER}@<kali-ip>"
echo "  4) Run ~/tools/discover/discover.sh and smile."
echo "Happy hunting. – N1PWN loadout deployed."
