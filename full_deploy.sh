#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -m MODE [-c CONTROLLER] [-v VARS_FILE] [-l LIMIT]

MODE:
  source    = Deploy source code saja (tanpa update .env)
  env       = Update .env saja (tanpa deploy source code)
  full      = Update .env + deploy source code (direkomendasikan)

Options:
  -c CONTROLLER    Controller host (default: ubuntu@192.168.11.110)
  -v VARS_FILE     Vars file untuk .env (default: pusher_vars.json, hanya untuk mode env/full)
  -l LIMIT         Ansible limit target (default: api_servers)

Examples:
  # Deploy source code saja (di kedua server)
  $0 -m source

  # Update .env saja (menggunakan pusher_vars.json)
  $0 -m env

  # Update .env + deploy source code (direkomendasikan untuk produksi)
  $0 -m full

  # Target hanya mpp-api02
  $0 -m full -l mpp-api02

  # Gunakan file vars berbeda
  $0 -m env -v my_custom_vars.json
EOF
  exit 1
}

MODE=""
CONTROLLER="ubuntu@192.168.11.110"
VARS_FILE="pusher_vars.json"
LIMIT="api_servers"

while getopts ":m:c:v:l:h" opt; do
  case ${opt} in
    m) MODE=${OPTARG} ;;
    c) CONTROLLER=${OPTARG} ;;
    v) VARS_FILE=${OPTARG} ;;
    l) LIMIT=${OPTARG} ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Error: MODE harus ditentukan (-m source|env|full)" >&2
  usage
fi

if [[ "$MODE" != "source" && "$MODE" != "env" && "$MODE" != "full" ]]; then
  echo "Error: MODE harus 'source', 'env', atau 'full'" >&2
  usage
fi

# Validasi file vars untuk mode env/full
if [[ "$MODE" == "env" || "$MODE" == "full" ]]; then
  if [ ! -f "$VARS_FILE" ]; then
    echo "Error: File vars '$VARS_FILE' tidak ditemukan di laptop" >&2
    exit 1
  fi
fi

REMOTE_VARS_PATH="/home/ubuntu/ansible/$(basename "$VARS_FILE")"

# ==================================================
# STEP 1: Update .env (jika mode env atau full)
# ==================================================
if [[ "$MODE" == "env" || "$MODE" == "full" ]]; then
  echo "=========================================="
  echo "STEP 1: Update .env di server"
  echo "=========================================="
  echo ""
  echo "1a. Mengirim $VARS_FILE ke controller..."
  scp "$VARS_FILE" "${CONTROLLER}:${REMOTE_VARS_PATH}"
  echo "✓ File terkirim ke $CONTROLLER:$REMOTE_VARS_PATH"
  echo ""

  echo "1b. Menjalankan update_env.yml di controller..."
  ssh "${CONTROLLER}" "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml -e @$(basename "$VARS_FILE") --limit ${LIMIT}"
  echo "✓ .env telah diperbarui di server"
  echo ""
fi

# ==================================================
# STEP 2: Deploy source code (jika mode source atau full)
# ==================================================
if [[ "$MODE" == "source" || "$MODE" == "full" ]]; then
  echo "=========================================="
  echo "STEP 2: Deploy source code di server"
  echo "=========================================="
  echo ""
  ssh "${CONTROLLER}" "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini deploy_playbook.yml --limit ${LIMIT}"
  echo "✓ Source code telah di-deploy"
  echo ""
fi

echo "=========================================="
echo "✓✓✓ SELESAI! ✓✓✓"
echo "=========================================="
echo "Mode: $MODE"
echo "Target: $LIMIT"
echo "Controller: $CONTROLLER"
