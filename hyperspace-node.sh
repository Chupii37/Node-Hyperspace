#!/bin/bash

# Definisikan warna untuk output yang lebih mudah dibaca
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'  # Tanpa warna (reset)

# Variabel untuk konfigurasi dan status
MODEL_DIR="/root/models"
STATUS_FILE="/root/status.txt"
LOG_FILE="/root/log.txt"
MAX_DOWNLOAD_TIME=3600  # Batas waktu pengunduhan model dalam detik (1 jam)

# Fungsi untuk membuat direktori model jika belum ada
setup_directories() {
  mkdir -p "$MODEL_DIR"
}

# Langkah pertama: Setup lingkungan dan dependencies (sekali saja)
setup_environment() {
  echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

  # Mengunduh dan memeriksa Logo.sh
  echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
  wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
  if [[ $? -ne 0 ]]; then
      echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
      exit 1
  fi
  cat Logo.sh  # Verifikasi konten skrip
  bash Logo.sh  # Menjalankan Logo.sh

  # Update sistem
  echo -e "${BLUE}Memastikan sistem sudah terupdate...${NC}"
  apt update -y && apt upgrade -y
}

# Meminta input private key dan menyimpannya
get_private_key() {
  echo -e "${CYAN}Silakan masukkan private key...${NC}"
  read -p "Masukkan private key: " private_key

  # Menyimpan private key ke file my.pem dan atur hak akses
  echo -e "$private_key" > /root/my.pem
  chmod 600 /root/my.pem
  echo -e "${GREEN}Private key telah disimpan dengan nama my.pem dan hak akses sudah diatur.${NC}"
}

# Memeriksa apakah Docker terinstal, jika belum instal
check_and_install_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker tidak ditemukan. Menginstal Docker...${NC}"
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update -y
    apt install -y docker-ce
    systemctl start docker
    systemctl enable docker
  else
    echo -e "${GREEN}Docker sudah terinstal!${NC}"
  fi
}

# Menarik dan menjalankan kontainer Docker
pull_and_run_docker() {
  echo -e "${BLUE}Menarik image Docker kartikhyper/aios...${NC}"
  docker pull kartikhyper/aios

  container_running=$(docker ps -q -f name=aios-container)
  if [ -z "$container_running" ]; then
    echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    docker run -d --restart unless-stopped --name aios-container -v /root:/root kartikhyper/aios bash -c "
      echo 'Memulai daemon...'
      /app/aios-cli start
    "
  else
    echo -e "${GREEN}Kontainer sudah berjalan.${NC}"
  fi
}

# Fungsi untuk menunggu kontainer siap, dengan batas waktu
wait_for_container_ready() {
  MAX_WAIT_TIME=3600  # Batas waktu maksimal 1 jam (3600 detik)
  WAIT_INTERVAL=10   # Interval pengecekan setiap 10 detik
  ELAPSED_TIME=0

  while true; do
    container_status=$(docker inspect --format '{{.State.Status}}' aios-container)
    
    if [[ "$container_status" == "running" ]]; then
      echo -e "${GREEN}Kontainer sudah siap.${NC}"
      break
    fi

    if [[ $ELAPSED_TIME -ge $MAX_WAIT_TIME ]]; then
      echo -e "${RED}Kontainer gagal untuk memulai dalam waktu yang ditentukan (${MAX_WAIT_TIME} detik).${NC}"
      exit 1
    fi

    echo -e "${YELLOW}Kontainer masih dalam status '$container_status', menunggu... (${ELAPSED_TIME}/${MAX_WAIT_TIME} detik)${NC}"
    sleep $WAIT_INTERVAL
    ELAPSED_TIME=$((ELAPSED_TIME + WAIT_INTERVAL))
  done
}

# Mengunduh model dengan pengecekan waktu pengunduhan
download_model() {
  local model_name=$1
  local start_time
  local elapsed_time

  echo -e "${BLUE}📥 Mengunduh model $model_name...${NC}"

  start_time=$(date +%s)
  echo "$model_name sedang diunduh" > "$STATUS_FILE"
  docker pull "$model_name" &>> "$LOG_FILE"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Model $model_name berhasil diunduh!${NC}"
    rm -f "$STATUS_FILE"
    return 0  # Pengunduhan berhasil
  fi

  elapsed_time=$(( $(date +%s) - start_time ))
  if [[ $elapsed_time -ge $MAX_DOWNLOAD_TIME ]]; then
    echo -e "${RED}Waktu pengunduhan model $model_name melebihi batas 1 jam. Model ini dilewatkan...${NC}"
    rm -f "$STATUS_FILE"
    return 1
  else
    echo -e "${RED}Pengunduhan model $model_name gagal.${NC}"
    rm -f "$STATUS_FILE"
    return 1
  fi
}

# Membersihkan model yang sudah lebih dari 6 jam
cleanup_old_models() {
  echo -e "${BLUE}Mengecek model yang sudah lebih dari 6 jam...${NC}"
  current_time=$(date +%s)

  for model in "$MODEL_DIR"/*; do
    if [ -f "$model" ]; then
      model_time=$(stat --format=%Y "$model")
      let "age=$current_time-$model_time"
      
      # Pastikan age tidak nol sebelum dibagi
      if [ "$age" -gt 0 ]; then
        let "age_in_hours=$age/3600"
        
        if [ "$age_in_hours" -ge 6 ]; then
          echo -e "${RED}Menghapus model $model yang sudah lebih dari 6 jam...${NC}"
          rm -rf "$model"
        fi
      else
        echo -e "${YELLOW}Model $model baru saja dibuat atau tidak valid untuk penghapusan.${NC}"
      fi
    fi
  done
}

# Fungsi untuk mendownload model acak
download_random_model() {
  echo -e "${BLUE}Mendapatkan daftar model yang tersedia...${NC}"
  available_models=$(docker exec aios-container /app/aios-cli models available)
  models=($(echo "$available_models" | grep 'model:' | awk '{print $2}'))
  selected_model=${models[$RANDOM % ${#models[@]}]}

  echo -e "${GREEN}Menarik model $selected_model...${NC}"
  docker exec aios-container /app/aios-cli models add "$selected_model"
  docker exec aios-container /app/aios-cli save-model "$selected_model" "$MODEL_DIR/$selected_model"
}

# Menjalankan inferensi dengan model dan prompt
run_inference() {
  prompts=( 
    "Can you explain how to write an HTTP server in Rust?" 
    "What are the best practices for containerizing applications with Docker?" 
    "Explain async/await in programming."
  )

  selected_prompt=${prompts[$RANDOM % ${#prompts[@]}]}
  echo -e "${BLUE}Menggunakan prompt: '$selected_prompt' untuk model $selected_model...${NC}"
  docker exec aios-container /app/aios-cli infer --model "$selected_model" --prompt "$selected_prompt"
}

# Mengimpor private key ke Hive dan login
import_private_key_to_hive() {
  echo -e "${CYAN}Mengimpor private key ke Hive...${NC}"
  docker exec aios-container /app/aios-cli hive import-keys /root/my.pem

  echo -e "${CYAN}Login ke Hive...${NC}"
  docker exec aios-container /app/aios-cli hive login
}

# Menampilkan model yang dibutuhkan untuk tier tertentu (misalnya, tier 4)
select_hive_tier() {
  echo -e "${BLUE}Menampilkan model yang dibutuhkan untuk tier 4...${NC}"
  docker exec aios-container /app/aios-cli hive select-tier 4
}

# Menghubungkan ke jaringan Hive
connect_to_hive_network() {
  echo -e "${BLUE}Menghubungkan ke jaringan Hive...${NC}"
  docker exec aios-container /app/aios-cli hive connect
}

# Fungsi untuk menjalankan inferensi melalui jaringan Hive
run_network_inference() {
  echo -e "${BLUE}Menjalankan inferensi melalui jaringan dengan model yang sama...${NC}"
  docker exec aios-container /app/aios-cli hive infer --model "$selected_model" --prompt "$selected_prompt"
}

# Fungsi utama untuk menjalankan proses secara berkelanjutan
main() {
  setup_directories
  setup_environment
  get_private_key
  check_and_install_docker
  pull_and_run_docker
  wait_for_container_ready
  download_model "kartikhyper/aios"
  cleanup_old_models
  download_random_model
  run_inference
  import_private_key_to_hive
  select_hive_tier
  connect_to_hive_network
  run_network_inference
}

# Jalankan skrip utama
main
