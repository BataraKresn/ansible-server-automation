## Full Deployment Workflow (dari Laptop ke Server via Controller)

### Alur Umum

```
Laptop
  ├─ pusher_vars.json (file .env vars)
  │
  └─> SSH ke Controller (192.168.11.110)
       │
       ├─ Jalankan update_env.yml (update .env di server)
       ├─ Jalankan deploy_playbook.yml (deploy source code di server)
       │
       └─> Ansible terhubung ke kedua server
            ├─ api-mpp (192.168.11.120)
            └─ mpp-api02 (192.168.11.141)
```

---

### Tiga Skenario Deployment

#### Skenario 1: Update Source Code Saja

**Kapan**: Hanya ada perubahan source code, `.env` tidak berubah.

**Step dari laptop**:
```bash
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini deploy_playbook.yml --limit api_servers"
```

Atau pakai skrip unified:
```bash
./full_deploy.sh -m source
```

**Apa yang terjadi**:
1. Playbook `deploy_playbook.yml` berjalan di controller.
2. Controller SSH ke kedua server.
3. Di tiap server, jalankan `/home/ubuntu/mpp-new/mpp-mobile-backend_1/deploy.sh`.
4. Script deploy akan pull source code (git pull atau sesuai setup).

---

#### Skenario 2: Update `.env` Saja

**Kapan**: Hanya ada perubahan variabel `.env` (mis. Pusher config), source code tidak berubah.

**File yang disiapkan di laptop**:
- `pusher_vars.json` (berisi konfigurasi Pusher terbaru)

**Step dari laptop**:
```bash
scp pusher_vars.json ubuntu@192.168.11.110:/home/ubuntu/ansible/
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml -e @pusher_vars.json --limit api_servers"
```

Atau pakai skrip unified:
```bash
./full_deploy.sh -m env
```

**Apa yang terjadi**:
1. File `pusher_vars.json` dikirim ke controller.
2. Playbook `update_env.yml` berjalan di controller.
3. Controller SSH ke kedua server.
4. Di tiap server:
   - Cek apakah `.env` ada → backup jika ada.
   - Update/append setiap `KEY=VALUE` dari `pusher_vars.json`.
   - Tampilkan verifikasi hasil.

---

#### Skenario 3: Update `.env` + Deploy Source Code (Rekomendasi)

**Kapan**: Ada perubahan baik `.env` maupun source code (kasus paling umum di produksi).

**File yang disiapkan di laptop**:
- `pusher_vars.json` (berisi konfigurasi Pusher terbaru)

**Step dari laptop**:
```bash
scp pusher_vars.json ubuntu@192.168.11.110:/home/ubuntu/ansible/
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml -e @pusher_vars.json --limit api_servers && ansible-playbook -i hosts.ini deploy_playbook.yml --limit api_servers"
```

Atau pakai skrip unified (REKOMENDASI):
```bash
./full_deploy.sh -m full
```

**Apa yang terjadi**:
1. File `pusher_vars.json` dikirim ke controller.
2. **STEP 1**: Update `.env` di kedua server (dengan backup).
3. **STEP 2**: Deploy source code di kedua server.

---

### Skrip Unified `full_deploy.sh`

Menyederhanakan semua skenario menjadi satu skrip dengan opsi `-m MODE`.

**Cara pakai**:

```bash
# Skenario 1: Update source code saja
./full_deploy.sh -m source

# Skenario 2: Update .env saja
./full_deploy.sh -m env

# Skenario 3: Update .env + deploy source code (REKOMENDASI)
./full_deploy.sh -m full

# Target hanya mpp-api02 (server kedua)
./full_deploy.sh -m full -l mpp-api02

# Gunakan file vars berbeda
./full_deploy.sh -m env -v my_custom_vars.json

# Controller berbeda
./full_deploy.sh -m full -c ubuntu@192.168.1.100
```

**Apa yang dilakukan di balik layar**:
- Mode `source`: Jalankan `deploy_playbook.yml` saja.
- Mode `env`: `scp` vars file + jalankan `update_env.yml` saja.
- Mode `full`: `scp` vars file + jalankan `update_env.yml` + jalankan `deploy_playbook.yml`.

---

### Detail Teknis

#### File yang ada di Controller (`/home/ubuntu/ansible/`)

- `hosts.ini` — inventory (daftar server: api-mpp, mpp-api02)
- `deploy_playbook.yml` — playbook deploy source code
- `update_env.yml` — playbook update .env
- `pusher_vars.json` — file vars (dikirim dari laptop via `scp`)

#### File yang ada di Server (`/home/ubuntu/mpp-new/mpp-mobile-backend_1/`)

- `.env` — file environment (akan di-update oleh `update_env.yml`)
- `deploy.sh` — script deploy (akan dijalankan oleh `deploy_playbook.yml`)

#### Backup & Rollback

Setiap kali `update_env.yml` berjalan:
- Backup `.env` ke `.env.bak_<epoch>` (remote di server).
- Jika ada masalah, restore manual:
  ```bash
  ssh ubuntu@<server> "cp /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env.bak_<epoch> /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env"
  ```

---

### Checklist Sebelum Deploy

- [ ] File `pusher_vars.json` sudah ada di laptop dan berisi nilai terbaru.
- [ ] SSH ke controller (192.168.11.110) bisa tanpa password (setup SSH key).
- [ ] File `.env` sudah ada di tiap server (`/home/ubuntu/mpp-new/mpp-mobile-backend_1/.env`).
- [ ] Script `deploy.sh` sudah ada dan bisa dijalankan di server.
- [ ] Tahu target mana: kedua server (`api_servers`) atau satu server saja (`-l mpp-api02`).

---

### Troubleshooting

**Q: "Permission denied" saat `scp`**
A: Setup SSH key dari laptop ke controller. Lakukan sekali saja:
```bash
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
ssh-copy-id ubuntu@192.168.11.110
```

**Q: Playbook gagal, bagaimana rollback?**
A: 
- Untuk `.env`: Restore dari backup `.env.bak_<epoch>`.
- Untuk source code: Jalankan `deploy.sh` lagi atau manual revert di server.

**Q: Mau jalankan hanya di server kedua?**
A: Pakai `-l mpp-api02`:
```bash
./full_deploy.sh -m full -l mpp-api02
```

---

### File-File Pendukung

- `update_env.yml` — Ansible playbook untuk update .env (idempotent, backup).
- `deploy_playbook.yml` — Ansible playbook untuk deploy source code.
- `hosts.ini` — Inventory Ansible.
- `pusher_vars.json` — Contoh file vars untuk Pusher config.
- `full_deploy.sh` — Skrip unified untuk deployment (rekomendasi).
