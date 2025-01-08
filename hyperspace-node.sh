#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # Reset

LOG_FILE="/root/script_progress.log"

# Helper function to log messages and steps
log_message() {
    echo -e "$1"
    echo "$(date): $1" >> $LOG_FILE
}

wait_for_user() {
  read -p "Apakah Anda ingin melanjutkan? (yes/no): " answer
  if [[ "$answer" != "yes" ]]; then
    log_message "❌ Proses dibatalkan."
    exit 1
  fi
}

# Retry function
retry() {
    local n=1
    local max=5
    local delay=10
    while true; do
        "$@" && return 0
        if (( n == max )); then
            return 1
        else
            echo "Attempt $n/$max failed! Retrying in $delay seconds..."
            sleep $delay
        fi
        ((n++))
    done
}

# Ensure system is updated
log_message "${BLUE}Memastikan sistem sudah terupdate...${NC}"
retry apt update -y && apt upgrade -y
if [[ $? -ne 0 ]]; then
    log_message "❌ Gagal memperbarui sistem."
    exit 1
fi
log_message "${GREEN}Sistem berhasil diperbarui.${NC}"

wait_for_user

# Download and check Logo.sh
log_message "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
retry wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
if [[ $? -ne 0 ]]; then
    log_message "❌ Gagal mengunduh Logo.sh."
    exit 1
fi
cat Logo.sh
bash Logo.sh

# Function to get the private key
get_private_key() {
  log_message "${CYAN}Silakan masukkan private key...${NC}"
  read -p "Masukkan private key: " private_key
  echo -e "$private_key" > /root/my.pem
  chmod 600 /root/my.pem
  log_message "${GREEN}Private key telah disimpan dengan nama my.pem dan hak akses sudah diatur.${NC}"
}

# Check and install Docker
check_and_install_docker() {
  if ! command -v docker &> /dev/null; then
    log_message "${RED}Docker tidak ditemukan. Menginstal Docker...${NC}"
    retry apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - 
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    retry apt update -y
    retry apt install -y docker-ce
    systemctl start docker
    systemctl enable docker
    if [[ $? -ne 0 ]]; then
        log_message "❌ Gagal menginstal Docker."
        exit 1
    fi
    log_message "${GREEN}Docker berhasil diinstal dan dijalankan.${NC}"
  else
    log_message "${GREEN}Docker sudah terinstal!${NC}"
  fi
}

# Start Docker container
start_container() {
    log_message "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    retry docker run -d --name aios-container -v /root:/root kartikhyper/aios /app/aios-cli start
    if [[ $? -ne 0 ]]; then
        log_message "❌ Gagal menjalankan kontainer."
        exit 1
    fi
    log_message "${GREEN}Kontainer berhasil dijalankan.${NC}"
}

wait_for_container_to_start() {
    log_message "${CYAN}Menunggu kontainer Docker untuk memulai (60 detik)...${NC}"
    sleep 60
}

# Check daemon status
check_daemon_status() {
    log_message "${BLUE}Memeriksa status daemon di dalam kontainer...${NC}"
    docker exec -it aios-container /app/aios-cli status
    if [[ $? -ne 0 ]]; then
        log_message "${RED}❌ Daemon tidak berjalan, mencoba untuk memulai ulang...${NC}"
        docker exec -it aios-container /app/aios-cli kill
        sleep 2
        docker exec -it aios-container /app/aios-cli start
        log_message "${GREEN}Daemon berhasil dimulai ulang.${NC}"
    else
        log_message "${GREEN}Daemon sudah berjalan.${NC}"
    fi
}

# Install local model
install_local_model() {
    log_message "${BLUE}Menginstal model lokal...${NC}"
    docker exec -it aios-container /app/aios-cli models add hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf
}

# Run inference
run_infer() {
    log_message "${CYAN}Apakah Anda ingin menjalankan infer dengan model yang telah diinstal? (yes/no)${NC}"
    read -p "Masukkan jawaban: " answer
    if [[ "$answer" != "yes" ]]; then
        log_message "❌ Proses infer dibatalkan."
        exit 1
    fi
    log_message "${BLUE}Menjalankan infer menggunakan model yang telah diinstal...${NC}"
    retry docker exec -it aios-container /app/aios-cli infer --model hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf --prompt "Explain a simple HTTP server in Rust."
    if [[ $? -ne 0 ]]; then
        log_message "❌ Gagal menjalankan infer."
        exit 1
    fi
    log_message "${GREEN}Infer berhasil dijalankan.${NC}"
}

# Run Hive inference
run_hive_infer() {
    log_message "${CYAN}Apakah Anda ingin menjalankan infer Hive menggunakan model yang telah diinstal? (yes/no)${NC}"
    read -p "Masukkan jawaban: " answer
    if [[ "$answer" != "yes" ]]; then
        log_message "❌ Proses infer Hive dibatalkan."
        exit 1
    fi
    log_message "${BLUE}Menjalankan infer Hive menggunakan model yang telah diinstal...${NC}"
    retry docker exec -it aios-container /app/aios-cli hive infer --model hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf --prompt "Explain a simple HTTP server in Rust."
    if [[ $? -ne 0 ]]; then
        log_message "❌ Gagal menjalankan infer Hive."
        exit 1
    fi
    log_message "${GREEN}Infer Hive berhasil dijalankan.${NC}"
}

# Function to check hive points
check_hive_points() {
    log_message "${BLUE}Memeriksa multiplier dan poin Hive...${NC}"
    docker exec -it aios-container /app/aios-cli hive points
    if [[ $? -ne 0 ]]; then
        log_message "❌ Gagal memeriksa multiplier dan poin Hive."
        exit 1
    fi
    log_message "${GREEN}Poin dan multiplier Hive berhasil diperiksa.${NC}"
}

# Function to check currently signed-in keys
get_current_signed_in_keys() {
    log_message "${BLUE}Mendapatkan kunci yang sedang login saat ini...${NC}"
    docker exec -it aios-container /app/aios-cli hive whoami
}

# Main script flow
check_and_install_docker
get_private_key
start_container
wait_for_container_to_start
check_daemon_status
install_local_model
run_infer
run_hive_infer
check_hive_points
get_current_signed_in_keys

log_message "${GREEN}Semua langkah berhasil dilakukan!${NC}"
