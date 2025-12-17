**Purpose**: quick examples to update `.env` on remote hosts from this repo.

- **CLI (SSH)**: `update_env.sh` — simple script that connects via SSH and updates or appends KEY=VALUE lines.

Usage examples:

```
# Update two variables on host 192.168.11.141
./update_env.sh -H 192.168.11.141 -p /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env FOO=bar BAZ=qux

# Update on inventory host name (makes sense if your SSH config or DNS resolves it)
./update_env.sh -H mpp-api02 -p /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env SECRET=topsecret
```

- **Ansible**: `update_env.yml` — idempotent playbook using `lineinfile`.

Example (pass variables as JSON/YAML via `--extra-vars` and target a single host with `--limit`):

```
ansible-playbook -i hosts.ini update_env.yml \
  --extra-vars '{"env_path":"/home/ubuntu/mpp-new/mpp-mobile-backend_1/.env","env_vars":{"FOO":"bar","BAZ":"qux"}}' \
  --limit mpp-api02
```

Notes:
- Make sure `ansible_user` in `hosts.ini` (or `-u`) matches the remote user (default `ubuntu`).
- If using VPN and running remotely via an SSH jump to your controller, you can run the playbook from the controller via:

```
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini deploy_playbook.yml"
```

Replace `deploy_playbook.yml` with `update_env.yml` and add `--extra-vars` as shown.
