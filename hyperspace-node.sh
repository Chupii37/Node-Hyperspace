#!/bin/bash

# Definisikan warna
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'  # Tanpa warna (reset)

# Direktori model dan status pengunduhan
MODEL_DIR="/root/models"
STATUS_FILE="/root/status.txt"
LOG_FILE="/root/log.txt"
MAX_DOWNLOAD_TIME=3600  # Batas waktu pengunduhan model dalam detik (1 jam)

# Membuat direktori untuk menyimpan model jika belum ada
mkdir -p "$MODEL_DIR"

# Langkah pertama: hanya dijalankan sekali, bukan diulang
setup_environment() {
  # Menampilkan Logo
  echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

  # Mengunduh dan memeriksa Logo.sh (Menambahkan verifikasi)
  echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
  wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
  if [[ $? -ne 0 ]]; then
      echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
      exit 1
  fi
  cat Logo.sh  # Verifikasi konten skrip
  bash Logo.sh  # Menjalankan Logo.sh

  # Memastikan sistem terupdate
  echo -e "${BLUE}Memastikan sistem sudah terupdate...${NC}"
  apt update -y && apt upgrade -y

  # Memastikan Docker sudah terinstal
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker tidak ditemukan. Menginstal Docker...${NC}"
    # Instalasi Docker
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update -y
    apt install -y docker-ce
    # Menjalankan Docker agar berjalan setelah instalasi
    systemctl start docker
    systemctl enable docker
  else
    echo -e "${GREEN}Docker sudah terinstal!${NC}"
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
}

# Fungsi untuk mengunduh model dengan verifikasi dan melanjutkan ke model lain jika gagal dalam 1 jam
download_model() {
  local model_name=$1
  local start_time
  local elapsed_time

  echo -e "${BLUE}📥 Mengunduh model $model_name...${NC}"
  
  # Melacak waktu mulai pengunduhan
  start_time=$(date +%s)
  
  # Tandai model yang sedang diunduh
  echo "$model_name sedang diunduh" > "$STATUS_FILE"
  
  # Mengunduh model
  docker pull "$model_name" &>> "$LOG_FILE"
  
  # Mengecek apakah pengunduhan selesai dengan benar
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Model $model_name berhasil diunduh!${NC}"
    # Tandai pengunduhan selesai
    rm -f "$STATUS_FILE"
    return 0  # Pengunduhan berhasil
  fi
  
  # Cek apakah waktu pengunduhan melebihi 1 jam
  elapsed_time=$(( $(date +%s) - start_time ))
  
  if [[ $elapsed_time -ge $MAX_DOWNLOAD_TIME ]]; then
    echo -e "${RED}Waktu pengunduhan model $model_name melebihi batas 1 jam. Model ini dilewatkan...${NC}"
    rm -f "$STATUS_FILE"  # Hapus status pengunduhan
    return 1  # Gagal dalam 1 jam, lewati model ini
  else
    echo -e "${RED}Pengunduhan model $model_name gagal. Model ini dilewatkan...${NC}"
    rm -f "$STATUS_FILE"  # Hapus status pengunduhan
    return 1  # Gagal, lewati model ini
  fi
}

# Fungsi untuk menghapus model yang sudah lebih dari 6 jam
cleanup_old_models() {
  echo -e "${BLUE}Mengecek model yang sudah lebih dari 6 jam...${NC}"
  current_time=$(date +%s)

  for model in "$MODEL_DIR"/*; do
    if [ -f "$model" ]; then
      model_time=$(stat --format=%Y "$model")
      let "age=$current_time-$model_time"
      let "age_in_hours=$age/3600"
      
      if [ "$age_in_hours" -ge 6 ]; then
        echo -e "${RED}Menghapus model $model yang sudah lebih dari 6 jam...${NC}"
        rm -rf "$model"
      fi
    fi
  done
}

# Fungsi untuk mendownload model acak setiap jam
download_random_model() {
  echo -e "${BLUE}Mendapatkan daftar model yang tersedia...${NC}"
  available_models=$(docker exec aios-container aios-cli models available)

  # Menyaring model dan memilih model acak
  models=($(echo "$available_models" | grep 'model:' | awk '{print $2}'))
  selected_model=${models[$RANDOM % ${#models[@]}]}

  echo -e "${GREEN}Menarik model $selected_model...${NC}"

  # Menyimpan model yang dipilih ke direktori
  docker exec aios-container aios-cli models add "$selected_model"
  docker exec aios-container aios-cli save-model "$selected_model" "$MODEL_DIR/$selected_model"

  echo -e "${CYAN}Model $selected_model berhasil diunduh!${NC}"
}

# Fungsi untuk menjalankan inferensi dengan prompt dan model yang dipilih
run_inference() {
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
  echo -e "${BLUE}Menggunakan prompt: '$selected_prompt' untuk model $selected_model...${NC}"

  # Menjalankan inferensi dengan model yang dipilih dan prompt yang sesuai
  docker exec aios-container aios-cli infer --model "$selected_model" --prompt "$selected_prompt"
}

# Fungsi untuk mengimpor private key ke Hive dan login
import_private_key_to_hive() {
  echo -e "${CYAN}Mengimpor private key ke hive...${NC}"
  docker exec aios-container aios-cli hive import-keys /root/my.pem

  echo -e "${CYAN}Login ke hive...${NC}"
  docker exec aios-container aios-cli hive login
}

# Fungsi untuk menampilkan model yang dibutuhkan untuk tier tertentu
select_hive_tier() {
  echo -e "${BLUE}Menampilkan model yang dibutuhkan untuk tier 4...${NC}"
  docker exec aios-container aios-cli hive select-tier 4
}

# Fungsi untuk menghubungkan ke jaringan Hive
connect_to_hive_network() {
  echo -e "${BLUE}Menghubungkan ke jaringan...${NC}"
  docker exec aios-container aios-cli hive connect
}

# Fungsi untuk menjalankan inferensi melalui jaringan Hive
run_network_inference() {
  echo -e "${BLUE}Menjalankan inferensi melalui jaringan dengan model yang sama...${NC}"
  docker exec aios-container aios-cli hive infer --model "$selected_model" --prompt "$selected_prompt"
}

# Langkah pertama hanya sekali dijalankan
setup_environment

# Menjalankan proses setiap jam setelah setup selesai
while true; do
  # Membersihkan model yang sudah lebih dari 6 jam
  cleanup_old_models
  
  # Mengunduh model acak
  download_random_model
  
  # Mengimpor private key ke Hive dan login
  import_private_key_to_hive
  
  # Menampilkan model untuk tier 4
  select_hive_tier
  
  # Menghubungkan ke jaringan Hive
  connect_to_hive_network
  
  # Menjalankan inferensi melalui jaringan Hive
  run_network_inference

  # Menunggu 1 jam sebelum mengunduh model berikutnya
  sleep 3600  # 1 jam
done
