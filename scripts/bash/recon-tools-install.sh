#!/usr/bin/env bash
set -Eeuo pipefail

log()  { echo -e "[+] $*"; }
warn() { echo -e "[!] $*"; }

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
TOOLS_DIR="$HOME_DIR/tools/recon"

run_as_user() {
  sudo -u "$USER_NAME" -H bash -lc "$*"
}

log "Creating recon tools directory"
sudo mkdir -p "$TOOLS_DIR"
sudo chown -R "$USER_NAME:$USER_NAME" "$TOOLS_DIR"

log "Installing base packages"
sudo apt update
sudo apt install -y git python3-venv python3-pip golang exiftool pdfgrep massdns

#################################
# Go-based tools
#################################
export GOPATH="$HOME_DIR/go"
export PATH="$PATH:$GOPATH/bin"

install_go() {
  local name="$1"
  local repo="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    log "Installing $name"
    run_as_user "go install $repo@latest"
  else
    warn "$name already installed"
  fi
}

install_go subfinder github.com/projectdiscovery/subfinder/v2/cmd/subfinder
install_go dnsx github.com/projectdiscovery/dnsx/cmd/dnsx
install_go httpx github.com/projectdiscovery/httpx/cmd/httpx
install_go naabu github.com/projectdiscovery/naabu/v2/cmd/naabu
install_go gau github.com/lc/gau/v2/cmd/gau
install_go waybackurls github.com/tomnomnom/waybackurls

#################################
# Git-based Python tools
#################################
clone_py() {
  local name="$1"
  local repo="$2"
  if [[ ! -d "$TOOLS_DIR/$name" ]]; then
    log "Cloning $name"
    run_as_user "cd '$TOOLS_DIR' && git clone $repo $name"
  else
    warn "$name already exists"
  fi
}

clone_py sherlock https://github.com/sherlock-project/sherlock.git
clone_py maigret https://github.com/soxoj/maigret.git
clone_py holehe https://github.com/megadose/holehe.git
clone_py whatsmyname https://github.com/WebBreacher/WhatsMyName.git
clone_py photon https://github.com/s0md3v/Photon.git
clone_py spiderfoot https://github.com/smicallef/spiderfoot.git
clone_py onionsearch https://github.com/megadose/OnionSearch.git
clone_py torbot https://github.com/DedSecInside/TorBot.git

#################################
# Python venv setup helper
#################################
setup_venv() {
  local dir="$1"
  if [[ -f "$dir/requirements.txt" ]]; then
    log "Setting up venv for $(basename "$dir")"
    run_as_user "
      cd '$dir' &&
      python3 -m venv venv &&
      source venv/bin/activate &&
      pip install --upgrade pip &&
      pip install -r requirements.txt
    "
  fi
}

for d in sherlock maigret holehe photon spiderfoot onionsearch torbot; do
  setup_venv "$TOOLS_DIR/$d"
done

log "Recon tools installation complete."
echo
log "Tools installed under: $TOOLS_DIR"
