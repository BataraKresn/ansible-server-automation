#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -H HOST [-u USER] -p PATH KEY=VALUE [KEY=VALUE ...]

Examples:
  # update two keys on mpp-api02 using default user ubuntu
  ./update_env.sh -H 192.168.11.141 -p /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env FOO=bar BAZ=qux

  # use hostname from inventory and default user
  ./update_env.sh -H mpp-api02 -p /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env SECRET=topsecret

Notes:
  - The script uses ssh to connect as the specified user (default ubuntu).
  - For each KEY=VALUE it will replace an existing line starting with KEY= or append the line if not present.
  - Ensure your SSH keys/agent are configured for the target host.
EOF
  exit 1
}

HOST=""
USER="ubuntu"
ENV_PATH=""

while getopts ":H:u:p:" opt; do
  case ${opt} in
    H) HOST=${OPTARG} ;;
    u) USER=${OPTARG} ;;
    p) ENV_PATH=${OPTARG} ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

if [ -z "$HOST" ] || [ -z "$ENV_PATH" ] || [ $# -lt 1 ]; then
  usage
fi

for kv in "$@"; do
  if [[ "$kv" != *=* ]]; then
    echo "Skipping invalid pair: $kv" >&2
    continue
  fi
  key="${kv%%=*}"
  value="${kv#*=}"

  # Build a safe remote command. We avoid complex quoting by using bash -lc on remote side
  remote_cmd=
  remote_cmd+="env_path='${ENV_PATH//'/"'"'/}'\n"
  remote_cmd+="key='${key//'/"'"'/}'\n"
  remote_cmd+="value='${value//'/"'"'/}'\n"
  remote_cmd+=$'if [ ! -f "$env_path" ]; then touch "$env_path"; fi\n'
  remote_cmd+=$'if grep -q "^$key=" "$env_path" 2>/dev/null; then sed -i "s|^$key=.*|$key=$value|" "$env_path"; else echo "$key=$value" >> "$env_path"; fi\n'

  ssh "${USER}@${HOST}" bash -lc "$remote_cmd"
  echo "Updated ${key} on ${HOST}:${ENV_PATH}"
done
