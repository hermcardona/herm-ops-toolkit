#!/usr/bin/env bash
#
# Herm Recon Workflow Launcher
# Fast, structured recon for a target or small network
#
# Usage:
#   ./herm-recon.sh -t <target> -p <project_name> [-o <output_dir>]
#
# Example:
#   ./herm-recon.sh -t 192.0.2.0/24 -p example-lab
#

set -euo pipefail

# ---------- Colors ----------
RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
BLU="\e[34m"
MAG="\e[35m"
CYN="\e[36m"
RST="\e[0m"

banner() {
    echo -e "${MAG}============================================================${RST}"
    echo -e "${CYN}          Herm Recon Workflow Launcher (N1PWN)               ${RST}"
    echo -e "${MAG}============================================================${RST}"
}

log_info()  { echo -e "${GRN}[+]${RST} $*"; }
log_warn()  { echo -e "${YEL}[!]${RST} $*"; }
log_error() { echo -e "${RED}[-]${RST} $*"; }

# ---------- Defaults ----------
TARGET=""
PROJECT=""
OUTDIR="$HOME/recon"

# ---------- Args ----------
usage() {
    echo "Usage: $0 -t <target> -p <project_name> [-o <output_dir>]"
    echo "  -t   Target (IP, CIDR, or hostname), e.g. 192.0.2.0/24"
    echo "  -p   Project name (used for folder/output names)"
    echo "  -o   Base output directory (default: \$HOME/recon)"
    exit 1
}

while getopts "t:p:o:h" opt; do
    case "$opt" in
        t) TARGET="$OPTARG" ;;
        p) PROJECT="$OPTARG" ;;
        o) OUTDIR="$OPTARG" ;;
        h|*) usage ;;
    esac
done

[[ -z "$TARGET"  || -z "$PROJECT" ]] && usage

banner

# ---------- Prep ----------
PROJECT_DIR="${OUTDIR}/${PROJECT}"
mkdir -p "$PROJECT_DIR"

log_info "Target        : $TARGET"
log_info "Project       : $PROJECT"
log_info "Output folder : $PROJECT_DIR"

# Log file for meta info
META_FILE="${PROJECT_DIR}/_recon_meta.txt"
{
    echo "Herm Recon Workflow Launcher"
    echo "Timestamp : $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "Target    : $TARGET"
    echo "Project   : $PROJECT"
    echo "OutDir    : $PROJECT_DIR"
    echo
} >> "$META_FILE"

# ---------- Dependency checks ----------
check_bin() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_warn "Tool '$1' not found in PATH. This phase will be skipped."
        return 1
    fi
    return 0
}

log_info "Checking core tools..."
HAS_NMAP=0
HAS_FFUF=0
HAS_SMBMAP=0
HAS_ENUM4LINUX=0
HAS_WHATWEB=0

if check_bin nmap;          then HAS_NMAP=1; fi
if check_bin ffuf;          then HAS_FFUF=1; fi
if check_bin smbmap;        then HAS_SMBMAP=1; fi
if check_bin enum4linux-ng; then HAS_ENUM4LINUX=1; fi
if check_bin whatweb;       then HAS_WHATWEB=1; fi

if [[ $HAS_NMAP -ne 1 ]]; then
    log_error "nmap is required. Install it and re-run."
    exit 1
fi

# ---------- Phase 1: All-port scan ----------
log_info "Phase 1: Full TCP port scan against $TARGET"
NMAP_ALL_BASE="${PROJECT_DIR}/nmap_allports"

# Fast-ish full scan: adjust min-rate if you want more/less aggression
sudo nmap -p- -T4 -n -Pn --max-retries 1 --min-rate 3000 \
    -oA "$NMAP_ALL_BASE" "$TARGET"

log_info "Saved full port scan to:"
log_info "  ${NMAP_ALL_BASE}.nmap"
log_info "  ${NMAP_ALL_BASE}.gnmap"
log_info "  ${NMAP_ALL_BASE}.xml"

# ---------- Phase 2: Per-host service scan ----------
log_info "Phase 2: Extracting hosts and open ports from gnmap"

GNMAP_FILE="${NMAP_ALL_BASE}.gnmap"
if [[ ! -f "$GNMAP_FILE" ]]; then
    log_error "Expected gnmap file not found: $GNMAP_FILE"
    exit 1
fi

HOSTS_PORTS_FILE="${PROJECT_DIR}/hosts_open_ports.txt"
> "$HOSTS_PORTS_FILE"

# Each line: Host <ip> () Ports: port/state/...
# We compress per host into: ip:port1,port2,...
while read -r line; do
    if [[ "$line" =~ ^Host ]]; then
        ip=$(echo "$line" | awk '{print $2}')
        ports=$(echo "$line" | grep -oP '[0-9]+/open' | cut -d'/' -f1 | sort -n | tr '\n' ',' | sed 's/,$//')
        if [[ -n "$ports" ]]; then
            echo "${ip}:${ports}" >> "$HOSTS_PORTS_FILE"
        fi
    fi
done < "$GNMAP_FILE"

if [[ ! -s "$HOSTS_PORTS_FILE" ]]; then
    log_warn "No open ports found in Phase 1. Double-check the target or try a less aggressive scan."
else
    log_info "Host/port mapping written to: $HOSTS_PORTS_FILE"
fi

log_info "Phase 2: Running targeted service scans per host"

while IFS=: read -r host ports; do
    [[ -z "$host" || -z "$ports" ]] && continue
    safe_host_name="${host//./_}"
    NMAP_SVC_BASE="${PROJECT_DIR}/nmap_services_${safe_host_name}"

    log_info "  -> $host on ports: $ports"
    sudo nmap -sV -sC -O -T4 -n -Pn -p"${ports}" \
        -oA "$NMAP_SVC_BASE" "$host"

    log_info "  Saved: ${NMAP_SVC_BASE}.nmap/.xml/.gnmap"

done < "$HOSTS_PORTS_FILE"

# ---------- Phase 3: Web enumeration ----------
log_info "Phase 3: Web enumeration (80/443/8080/8443) where applicable"

if [[ $HAS_WHATWEB -eq 0 && $HAS_FFUF -eq 0 ]]; then
    log_warn "No web tools (whatweb/ffuf) detected, skipping web-specific recon."
else
    WORDLIST="${FFUF_WORDLIST:-/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt}"
    if [[ ! -f "$WORDLIST" ]]; then
        log_warn "Wordlist not found at $WORDLIST, dir brute will be skipped unless you set \$FFUF_WORDLIST."
    fi

    while IFS=: read -r host ports; do
        [[ -z "$host" || -z "$ports" ]] && continue

        if echo "$ports" | grep -Eq '(80|443|8080|8443)'; then
            log_info "  Web-ish ports detected on $host ($ports)"

            # whatweb
            if [[ $HAS_WHATWEB -eq 1 ]]; then
                log_info "    -> Running whatweb on ${host}"
                whatweb "$host" > "${PROJECT_DIR}/${host}_whatweb.txt" 2>&1 || true
            fi

            # ffuf simple dir brute (http & https)
            if [[ $HAS_FFUF -eq 1 && -f "$WORDLIST" ]]; then
                for scheme in http https; do
                    URL="${scheme}://${host}/FUZZ"
                    OUT_JSON="${PROJECT_DIR}/ffuf_${host}_${scheme}.json"
                    log_info "    -> ffuf dir brute: $URL"
                    ffuf -w "$WORDLIST" -u "$URL" -mc 200,204,301,302,307,401,403,500 \
                         -o "$OUT_JSON" -of json 2>/dev/null || true
                done
            fi
        fi
    done < "$HOSTS_PORTS_FILE"
fi

# ---------- Phase 4: SMB enumeration ----------
log_info "Phase 4: SMB enumeration (139/445) where applicable"

if [[ $HAS_SMBMAP -eq 0 && $HAS_ENUM4LINUX -eq 0 ]]; then
    log_warn "smbmap/enum4linux-ng not found, skipping SMB recon."
else
    while IFS=: read -r host ports; do
        [[ -z "$host" || -z "$ports" ]] && continue

        if echo "$ports" | grep -Eiq '(139|445)'; then
            log_info "  SMB ports detected on $host ($ports)"

            if [[ $HAS_SMBMAP -eq 1 ]]; then
                log_info "    -> smbmap (anonymous) on $host"
                smbmap -H "$host" > "${PROJECT_DIR}/${host}_smbmap_anon.txt" 2>&1 || true
            fi

            if [[ $HAS_ENUM4LINUX -eq 1 ]]; then
                log_info "    -> enum4linux-ng (anonymous) on $host"
                enum4linux-ng -A "$host" > "${PROJECT_DIR}/${host}_enum4linux-ng.txt" 2>&1 || true
            fi
        fi
    done < "$HOSTS_PORTS_FILE"
fi

# ---------- Done ----------
log_info "Recon complete for project '$PROJECT'."
echo
echo -e "${BLU}Key outputs:${RST}"
echo "  - Full TCP scan        : ${NMAP_ALL_BASE}.nmap/.xml/.gnmap"
echo "  - Host/port mapping    : ${HOSTS_PORTS_FILE}"
echo "  - Per-host service scans: ${PROJECT_DIR}/nmap_services_<ip>.nmap"
echo "  - Web enum (if run)    : ${PROJECT_DIR}/*_whatweb.txt, ffuf_*.json"
echo "  - SMB enum (if run)    : ${PROJECT_DIR}/*_smbmap_anon.txt, *_enum4linux-ng.txt"
echo
log_info "Happy hunting, Herm. 🥷"
