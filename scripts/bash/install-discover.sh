#!/usr/bin/env bash
#
# N1PWN – Home-directory install of Lee Baird's Discover on ParrotOS
# Target location:  $HOME/tools/discover
# Creates launcher: $HOME/.local/bin/discover

set -e

echo "[*] Starting Discover home-directory install for Parrot OS..."

# ---------- Config ----------
TOOLS_DIR="$HOME/tools"
DISCOVER_DIR="$TOOLS_DIR/discover"
LAUNCHER_DIR="$HOME/.local/bin"
LAUNCHER_PATH="$LAUNCHER_DIR/discover"
REPO_URL="https://github.com/leebaird/discover.git"

# ---------- Prep ----------
echo "[*] Creating tools directory at: $TOOLS_DIR"
mkdir -p "$TOOLS_DIR"

echo "[*] Creating local bin directory at: $LAUNCHER_DIR"
mkdir -p "$LAUNCHER_DIR"

# ---------- Dependencies ----------
echo "[*] Updating package list and installing dependencies..."
sudo apt update

# Core dependencies – you can tweak this list if you want it leaner
sudo apt install -y \
    git curl wget nmap whois dnsutils \
    python3 python3-pip python3-venv \
    ruby ruby-full \
    chromium \
    sslscan \
    whatweb \
    dirb \
    xvfb \
    x11-utils \
    ca-certificates

# ---------- Grab Discover ----------
if [ -d "$DISCOVER_DIR" ]; then
    echo "[*] Discover directory already exists at $DISCOVER_DIR"
    echo "[*] Pulling latest changes from Git..."
    git -C "$DISCOVER_DIR" pull
else
    echo "[*] Cloning Discover into $DISCOVER_DIR..."
    git clone "$REPO_URL" "$DISCOVER_DIR"
fi

# ---------- Fix permissions ----------
echo "[*] Setting ownership and permissions..."
chmod +x "$DISCOVER_DIR/discover.sh" || true
find "$DISCOVER_DIR" -type f -name "*.sh" -exec chmod +x {} \; || true

# ---------- Optional: create a Python venv (safe sandbox) ----------
# Comment this whole block out if you don't want a venv

if [ ! -d "$DISCOVER_DIR/venv" ]; then
    echo "[*] Creating Python virtual environment for Discover..."
    python3 -m venv "$DISCOVER_DIR/venv"
    echo "[*] Installing Python requirements (if any)..."
    if [ -f "$DISCOVER_DIR/requirements.txt" ]; then
        "$DISCOVER_DIR/venv/bin/pip" install --upgrade pip
        "$DISCOVER_DIR/venv/bin/pip" install -r "$DISCOVER_DIR/requirements.txt"
    fi
else
    echo "[*] Python venv already exists at $DISCOVER_DIR/venv – skipping."
fi

# ---------- Create launcher ----------
echo "[*] Creating launcher at $LAUNCHER_PATH"

cat > "$LAUNCHER_PATH" << 'EOF'
#!/usr/bin/env bash
# Wrapper to launch Discover from the user's home directory

BASE_DIR="$HOME/tools/discover"

if [ ! -d "$BASE_DIR" ]; then
    echo "[!] Discover not found at $BASE_DIR"
    echo "    Did you move or delete it? Re-run the installer."
    exit 1
fi

# Activate venv if it exists (safe, optional)
if [ -d "$BASE_DIR/venv" ]; then
    source "$BASE_DIR/venv/bin/activate"
fi

cd "$BASE_DIR"

# Main launcher script in Discover repo
if [ -x "./discover.sh" ]; then
    ./discover.sh "$@"
else
    echo "[!] ./discover.sh not found or not executable in $BASE_DIR"
    exit 1
fi
EOF

chmod +x "$LAUNCHER_PATH"

# ---------- PATH check ----------
if ! echo "$PATH" | grep -q "$LAUNCHER_DIR"; then
    echo "[*] Adding $LAUNCHER_DIR to PATH in ~/.bashrc and ~/.zshrc (if present)..."
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    if [ -f "$HOME/.zshrc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    echo "[*] Reload your shell or run:  export PATH=\"\$HOME/.local/bin:\$PATH\""
# ---- N1PWN OSINT KEY BOOTSTRAP (optional) ----
if [ -x "$HOME/n1pwn-osint-bootstrap.sh" ]; then
    echo "[*] Running N1PWN OSINT Bootstrap..."
    "$HOME/n1pwn-osint-bootstrap.sh" || echo "[!] OSINT bootstrap failed – check output above."
else
    echo "[*] N1PWN OSINT Bootstrap script not found at ~/n1pwn-osint-bootstrap.sh"
    echo "    Create it later and run it manually to wire Recon-ng, theHarvester, and Amass."
fi


echo
echo "[+] Discover installation complete!"
echo "[+] Repo location:   $DISCOVER_DIR"
echo "[+] Launcher:        discover"
echo
echo "Usage:"
echo "  discover"
echo
