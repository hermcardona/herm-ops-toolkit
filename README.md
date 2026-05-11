# Herm Ops Toolkit

Curated operational scripts for authorized security testing and lab automation.

## What’s inside

- **Kali / workstation bootstrap** — idempotent setup patterns
- **OSINT bootstrap + key management** — safe defaults, no secret output
- **Recon workflow helpers** — repeatable pipelines

## Quickstart

```bash
ls -la scripts/bash
```

## `pentest-bash-kit/README.md`

````bash
cat > ~/github/pentest-bash-kit/README.md <<'EOF'
# Pentest Bash Kit

Reusable bash utilities for recon and lab operations.

## Conventions

- Every script should support `--help`
- No hardcoded client targets
- Safe defaults: avoid destructive ops without confirmation

## Run

```bash
ls -la bin/bash-scripts
```

EOF
````

## `python-offsec-toolbox/README.md`

````bash
cat > ~/github/python-offsec-toolbox/README.md <<'EOF'
# Python OffSec Toolbox

Small Python tools supporting authorized recon and testing workflows.

## Notes

Cookie output is **opt-in** via environment variable:

```bash
SHOW_COOKIES=1 python3 tools/http-recon.py
```

EOF
````

## `herm-portfolio/README.md`

```bash
cat > ~/github/herm-portfolio/README.md <<'EOF'
# Herm Security Portfolio

A curated index of my public tools and artifacts.

## Featured Repos

- **herm-ops-toolkit** — curated automation scripts
- **pentest-bash-kit** — bash utilities and workflows
- **python-offsec-toolbox** — Python utilities

## Featured Artifacts

- Red Team Master Binder — sanitized
- Engagement playbooks and checklists

EOF
```
