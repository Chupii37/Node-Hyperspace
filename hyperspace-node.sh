#!/bin/bash

# Definisikan warna
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'  # Tanpa warna (reset)

# Menampilkan Logo
echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

# Mengunduh dan menjalankan Logo.sh (Menambahkan verifikasi)
echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
    exit 1
fi
cat Logo.sh  # Verifikasi konten skrip
bash Logo.sh  # Menjalankan Logo.sh

# Meminta input private key
echo -e "${CYAN}Masukkan private key Anda:${NC}"
read private_key

# Memuat ulang konfigurasi bashrc untuk memastikan lingkungan terbaru
echo -e "${BLUE}Memuat ulang .bashrc...${NC}"
source /root/.bashrc

# Simpan private key ke file sementara
echo "$private_key" > /root/my.pem

# Mengubah izin file private key
echo -e "${CYAN}Mengubah izin file private key menjadi 600...${NC}"
chmod 600 /root/my.pem

# File lock untuk mencegah tumpang tindih
LOCK_FILE="/root/aios-script.lock"

# Memeriksa apakah skrip sedang berjalan (tumpang tindih)
if [ -e "$LOCK_FILE" ]; then
  echo -e "${YELLOW}Skrip sudah berjalan. Menunggu proses selesai...${NC}"
  exit 0  # Skrip sudah berjalan, keluar
else
  # Membuat file lock untuk menunjukkan skrip sedang berjalan
  touch "$LOCK_FILE"
fi

# Menarik image Docker kartikhyper/aios
echo -e "${BLUE}Menarik image Docker kartikhyper/aios...${NC}"
docker pull kartikhyper/aios

# Memeriksa apakah kontainer Docker sudah berjalan atau belum
container_running=$(docker ps -q -f name=aios-container)

if [ -z "$container_running" ]; then
  # Jika kontainer belum berjalan, mulai kontainer baru dengan auto restart
  echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
  docker run -d --restart unless-stopped --name aios-container -v /root:/root kartikhyper/aios bash -c "
    # Memulai daemon dalam kontainer Docker
    echo 'Memulai daemon...'
    aios-cli start
  "
else
  echo -e "${GREEN}Kontainer sudah berjalan. Melanjutkan proses selanjutnya...${NC}"
fi

# Melanjutkan skrip dari sini
echo -e "${BLUE}Menjalankan proses lainnya...${NC}"

# Mendapatkan daftar model yang tersedia
echo -e "${BLUE}Mendapatkan daftar model yang tersedia...${NC}"
available_models=$(docker exec aios-container aios-cli models available)

# Menyaring model dari output dan mengambil hanya nama model (disesuaikan dengan format output)
models=($(echo "$available_models" | grep 'model:' | awk '{print $2}'))

# Memilih model secara acak dari daftar model
selected_model=${models[$RANDOM % ${#models[@]}]}

# Daftar prompt yang berbeda yang akan digunakan untuk setiap model
prompts=(
  "Can you explain how to write an HTTP server in Rust?"
  "What are the best practices for containerizing applications with Docker?"
  "Explain the concept of async/await in programming."
  "How does machine learning work and what are its applications?"
  "What is quantum computing and how does it differ from classical computing?"
)

# Memilih prompt secara acak dari daftar prompt
selected_prompt=${prompts[$RANDOM % ${#prompts[@]}]}

# Menambahkan model yang dipilih secara lokal
echo -e "${GREEN}Menambahkan model $selected_model secara lokal...${NC}"
docker exec aios-container aios-cli models add "$selected_model"

# Menjalankan inferensi lokal dengan model yang dipilih dan prompt yang sesuai
echo -e "${CYAN}Menjalankan inferensi dengan model $selected_model dan prompt: $selected_prompt...${NC}"
docker exec aios-container aios-cli infer --model "$selected_model" --prompt "$selected_prompt"

# Mengimpor private key ke hive
echo -e "${CYAN}Mengimpor private key ke hive...${NC}"
docker exec aios-container aios-cli hive import-keys /root/my.pem

# Login ke hive menggunakan kunci yang diimpor
echo -e "${CYAN}Login ke hive...${NC}"
docker exec aios-container aios-cli hive login

# Menampilkan model yang dibutuhkan untuk tier tertentu
echo -e "${BLUE}Menampilkan model yang dibutuhkan untuk tier 4...${NC}"
docker exec aios-container aios-cli hive select-tier 4

# Menghubungkan ke jaringan untuk menyediakan inferensi
echo -e "${BLUE}Menghubungkan ke jaringan...${NC}"
docker exec aios-container aios-cli hive connect

# Menjalankan inferensi melalui orang lain di jaringan (menggunakan model yang sama)
echo -e "${BLUE}Menjalankan inferensi melalui jaringan dengan model yang sama...${NC}"
docker exec aios-container aios-cli hive infer --model "$selected_model" --prompt "$selected_prompt"

# Shortcut untuk memulai dan login/connect ke jaringan untuk hosting model lokal
echo -e "${CYAN}Memulai dan login/connect ke jaringan untuk hosting model lokal...${NC}"
docker exec aios-container aios-cli start --connect

echo -e "${GREEN}Proses selesai!${NC}"

# Menambahkan cron job untuk menghapus model setiap 24 jam
echo -e "${CYAN}Menambahkan cron job untuk menghapus model setiap 24 jam...${NC}"
if [ ! -f /root/cron_job_installed ]; then
  # Cron job untuk menghapus model setiap 24 jam
  echo '0 0 * * * docker exec aios-container aios-cli models remove --all' > /etc/cron.d/delete-models
  chmod 0644 /etc/cron.d/delete-models
  touch /root/cron_job_installed  # Tandai bahwa cron job telah ditambahkan
fi

# Memulai layanan cron
echo -e "${CYAN}Memulai layanan cron...${NC}"
service cron start

# Menghapus file lock setelah skrip selesai
rm -f "$LOCK_FILE"

echo -e "${GREEN}Cron job berhasil dijadwalkan untuk menghapus model setiap 24 jam.${NC}"
