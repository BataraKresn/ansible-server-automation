#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-c CONTROLLER] [-l LIMIT] [-v VARS_FILE]

Options:
  -c CONTROLLER    Controller host (default: ubuntu@192.168.11.110)
  -l LIMIT         Ansible limit (default: api_servers)
  -v VARS_FILE     Vars file path (default: pusher_vars.json)

Examples:
  # Update kedua server dengan pusher_vars.json
  ./deploy_env.sh

  # Update hanya mpp-api02 dengan custom vars file
  ./deploy_env.sh -l mpp-api02 -v my_vars.json

  # Update dengan controller berbeda
  ./deploy_env.sh -c ubuntu@192.168.1.100
EOF
  exit 1
}

CONTROLLER="ubuntu@192.168.11.110"
LIMIT="api_servers"
VARS_FILE="pusher_vars.json"

while getopts ":c:l:v:h" opt; do
  case ${opt} in
    c) CONTROLLER=${OPTARG} ;;
    l) LIMIT=${OPTARG} ;;
    v) VARS_FILE=${OPTARG} ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [ ! -f "$VARS_FILE" ]; then
  echo "Error: File '$VARS_FILE' tidak ditemukan" >&2
  exit 1
fi

REMOTE_PATH="/home/ubuntu/ansible/$(basename "$VARS_FILE")"

echo "Langkah 1: Mengirim $VARS_FILE ke controller ($CONTROLLER) ke $REMOTE_PATH"
scp "$VARS_FILE" "${CONTROLLER}:${REMOTE_PATH}"

echo ""
echo "Langkah 2: Menjalankan playbook di controller (limit: $LIMIT)"
ssh "${CONTROLLER}" "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml -e @$(basename "$VARS_FILE") --limit ${LIMIT}"

echo ""
echo "✓ Selesai! File .env di server telah diperbarui."
