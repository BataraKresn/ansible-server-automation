Purpose: Petunjuk ringkas dan contoh untuk memperbarui file `.env` pada server target menggunakan Ansible (direkomendasikan) atau CLI SSH sederhana.

Kapan pakai apa:
- Ansible (`update_env.yml`): direkomendasikan untuk perubahan terstruktur, banyak host, atau CI. Idempotent dan menggunakan `hosts.ini`.
- CLI (`update_env.sh`): cepat untuk perubahan satu-dua variabel langsung ke server tertentu via SSH.

Ringkasan alur (Anda menjalankan dari laptop):
1. Anda SSH ke controller (mis. `ubuntu@192.168.11.110`).
2. Dari controller menjalankan `ansible-playbook -i hosts.ini update_env.yml`.
3. Controller kemudian terhubung ke host di grup inventory (`api_servers`) untuk menerapkan perubahan.

Contoh variabel Pusher (yang ingin Anda tambahkan/ubah):
```
PUSHER_APP_ID=your_id
PUSHER_APP_KEY=your_key
PUSHER_APP_SECRET=your_secret
PUSHER_HOST=your_host
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1
```

Contoh 1 — pakai Ansible (`update_env.yml`) langsung pada kedua server (`api_servers`):
```bash
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml --extra-vars '{\"env_path\":\"/home/ubuntu/mpp-new/mpp-mobile-backend_1/.env\",\"env_vars\":{\"PUSHER_APP_ID\":\"your_id\",\"PUSHER_APP_KEY\":\"your_key\",\"PUSHER_APP_SECRET\":\"your_secret\",\"PUSHER_HOST\":\"your_host\",\"PUSHER_PORT\":\"443\",\"PUSHER_SCHEME\":\"https\",\"PUSHER_APP_CLUSTER\":\"mt1\"}}' --limit api_servers"
```

Contoh 2 — target hanya server kedua (`mpp-api02`):
```bash
ssh ubuntu@192.168.11.110 "export LC_ALL=C.UTF-8 LANG=C.UTF-8 && cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml --extra-vars '{\"env_path\":\"/home/ubuntu/mpp-new/mpp-mobile-backend_1/.env\",\"env_vars\":{\"PUSHER_APP_ID\":\"your_id\",\"PUSHER_APP_KEY\":\"your_key\",\"PUSHER_APP_SECRET\":\"your_secret\",\"PUSHER_HOST\":\"your_host\",\"PUSHER_PORT\":\"443\",\"PUSHER_SCHEME\":\"https\",\"PUSHER_APP_CLUSTER\":\"mt1\"}}' --limit mpp-api02"
```

Contoh 3a — gunakan file variabel YAML (lebih rapi untuk CI):
1. Buat file lokal `pusher_vars.yml` di laptop dengan isi seperti:
```yaml
env_path: /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env
env_vars:
  PUSHER_APP_ID: "your_id"
  PUSHER_APP_KEY: "your_key"
  PUSHER_APP_SECRET: "your_secret"
  PUSHER_HOST: "your_host"
  PUSHER_PORT: "443"
  PUSHER_SCHEME: "https"
  PUSHER_APP_CLUSTER: "mt1"
```
2. Salin ke controller lalu jalankan:
```bash
scp pusher_vars.yml ubuntu@192.168.11.110:/home/ubuntu/ansible/
ssh ubuntu@192.168.11.110 "cd /home/ubuntu/ansible && ansible-playbook -i hosts.ini update_env.yml -e @pusher_vars.yml --limit api_servers"
```

Contoh 4 — gunakan skrip otomatis `deploy_env.sh` (rekomendasi untuk workflow harian):
Skrip ini otomatis melakukan `scp` + jalankan playbook dengan satu perintah.

Dari laptop (di direktori dimana ada file `pusher_vars.json`):
```bash
./deploy_env.sh
```

Atau dengan opsi:
```bash
# Target hanya server kedua (mpp-api02)
./deploy_env.sh -l mpp-api02

# Gunakan file vars berbeda
./deploy_env.sh -v my_custom_vars.json

# Controller berbeda
./deploy_env.sh -c ubuntu@192.168.1.100
```

Perintah di balik layar yang dilakukan:
1. `scp pusher_vars.json ubuntu@192.168.11.110:/home/ubuntu/ansible/`
2. SSH ke controller dan jalankan: `ansible-playbook -i hosts.ini update_env.yml -e @pusher_vars.json --limit api_servers`



Apa yang dilakukan `update_env.yml` (aman untuk produksi):
- Memeriksa apakah file `.env` ada pada tiap host (`stat`).
- Jika ada, membuat backup remote: `{{ env_path }}.bak_<epoch>`.
- Memastikan `.env` ada (touch jika perlu).
- Untuk tiap pasangan `KEY: VALUE` di `env_vars`:
  - jika `KEY=` sudah ada → `lineinfile` mengganti nilainya (idempotent);
  - jika belum ada → `lineinfile` menambahkan baris `KEY=VALUE`.
- Setelah perubahan, playbook menampilkan baris-baris yang diubah untuk verifikasi.

Rollback singkat:
- Playbook membuat backup `{{ env_path }}.bak_<epoch>` pada setiap host ketika file awal ada.
- Untuk restore manual:
```bash
ssh ubuntu@<host> "cp /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env.bak_1234567890 /home/ubuntu/mpp-new/mpp-mobile-backend_1/.env"
```
Atau buat playbook restore untuk mengembalikan backup tertentu.

Tips CI / otomasi:
- Letakkan `pusher_vars.yml` atau file fragment (`env.fragment`) di repository pipeline, lalu dalam job CI lakukan `scp` ke controller dan jalankan perintah `ansible-playbook ... -e @pusher_vars.yml`.

Catatan tentang `hosts.ini` dan `api_servers`:
- Grup `api_servers` di `hosts.ini` menentukan host mana yang target jika Anda menjalankan playbook tanpa `--limit`.
- `ansible_user` di `hosts.ini` (atau `-u` CLI) menentukan user SSH yang digunakan controller untuk terhubung ke host-target.

Jika Anda mau, saya bisa:
- menambahkan contoh `pusher_vars.yml` ke repo, atau
- membuat playbook kecil `apply_env_fragment.yml` yang membaca file fragment yang Anda kirim ke controller dan menerapkannya (bagus untuk CI).
