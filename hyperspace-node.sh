#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # Reset

echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

# Menunggu konfirmasi dari pengguna untuk melanjutkan
wait_for_user() {
  read -p "Apakah Anda ingin melanjutkan? (yes/no): " answer
  if [[ "$answer" != "yes" ]]; then
    echo -e "${RED}❌ Proses dibatalkan.${NC}"
    exit 1
  fi
}

echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
    exit 1
fi
cat Logo.sh
bash Logo.sh

echo -e "${BLUE}Memastikan sistem sudah terupdate...${NC}"
apt update -y && apt upgrade -y
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal memperbarui sistem.${NC}"
    exit 1
fi
echo -e "${GREEN}Sistem berhasil diperbarui.${NC}"

# Fungsi untuk mendapatkan private key
get_private_key() {
  echo -e "${CYAN}Silakan masukkan private key...${NC}"
  read -s -p "Masukkan private key: " private_key
  echo -e "\n"
  echo -e "$private_key" > ./my.pem
  chmod 600 ./my.pem
  echo -e "${GREEN}Private key telah disimpan dengan nama my.pem dan hak akses sudah diatur.${NC}"
}

# Mengecek dan menginstal Docker jika diperlukan
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
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menginstal Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker berhasil diinstal dan dijalankan.${NC}"
  else
    echo -e "${GREEN}Docker sudah terinstal!${NC}"
  fi
}

# Fungsi untuk menjalankan kontainer
start_container() {
    echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    docker run -d --name aios-container -v /root:/root kartikhyper/aios /app/aios-cli start
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan kontainer.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kontainer berhasil dijalankan.${NC}"
}

# Fungsi untuk menunggu kontainer dan daemon berjalan
wait_for_container_to_start() {
    echo -e "${CYAN}Menunggu kontainer Docker untuk memulai (60 detik)...${NC}"
    sleep 60  # Tunggu 1 menit untuk kontainer memulai daemon
    
    # Verifikasi apakah kontainer berjalan dengan baik
    docker ps | grep aios-container &> /dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Kontainer Docker tidak berjalan. Pastikan kontainer dijalankan dengan benar.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kontainer Docker berhasil berjalan.${NC}"
}

# Memulai daemon di dalam kontainer
start_daemon() {
    echo -e "${BLUE}Masuk ke dalam kontainer dan memulai daemon...${NC}"
    
    # Cek apakah daemon sudah berjalan
    docker exec -it aios-container /app/aios-cli status
    if [[ $? -eq 0 ]]; then
        echo -e "${RED}Daemon sudah berjalan, menghentikan daemon yang sedang berjalan...${NC}"
        docker exec -it aios-container /app/aios-cli kill
        sleep 2  # Tunggu sebentar agar daemon berhenti
    fi
    
    # Memulai ulang daemon
    echo -e "${BLUE}Memulai daemon...${NC}"
    docker exec -it aios-container /app/aios-cli start
    
    echo -e "${CYAN}Menunggu daemon berjalan selama 10 detik...${NC}"
    timeout 10 docker exec -it aios-container /app/aios-cli status
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Daemon tidak berjalan, menghentikan dan memulai ulang...${NC}"
        docker exec -it aios-container /app/aios-cli kill
        sleep 2
        echo -e "${BLUE}Memulai ulang daemon...${NC}"
        docker exec -it aios-container /app/aios-cli start
    else
        echo -e "${GREEN}Daemon berhasil dijalankan.${NC}"
    fi
}

# Melihat model yang tersedia di dalam kontainer
view_available_models() {
    echo -e "${BLUE}Melihat model-model yang tersedia...${NC}"
    docker exec -it aios-container /app/aios-cli models available
}

# Menginstal model lokal
install_local_model() {
    echo -e "${BLUE}Menginstal model lokal...${NC}"
    docker exec -it aios-container /app/aios-cli models add hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf
}

# Menjalankan infer dengan model yang telah diinstal
run_infer() {
    echo -e "${CYAN}Apakah Anda ingin menjalankan infer dengan model yang telah diinstal? (yes/no)${NC}"
    read -p "Masukkan jawaban: " answer
    if [[ "$answer" != "yes" ]]; then
        echo -e "${RED}❌ Proses infer dibatalkan.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Menjalankan infer menggunakan model yang telah diinstal...${NC}"
    docker exec -it aios-container /app/aios-cli infer --model hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf --prompt "Can you explain how to write an HTTP server in Rust?"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan infer.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Infer berhasil dijalankan.${NC}"
}

# Menggunakan private key untuk login ke Hive
hive_login() {
    docker exec -it aios-container /app/aios-cli hive import-keys ./my.pem
    docker exec -it aios-container /app/aios-cli hive login
    docker exec -it aios-container /app/aios-cli hive select-tier 4
    docker exec -it aios-container /app/aios-cli hive connect
}

# Menjalankan infer Hive dengan model yang telah diinstal
run_hive_infer() {
    echo -e "${CYAN}Apakah Anda ingin menjalankan infer Hive menggunakan model yang telah diinstal? (yes/no)${NC}"
    read -p "Masukkan jawaban: " answer
    if [[ "$answer" != "yes" ]]; then
        echo -e "${RED}❌ Proses infer Hive dibatalkan.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Menjalankan infer Hive menggunakan model yang telah diinstal...${NC}"
    docker exec -it aios-container /app/aios-cli hive infer --model hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf --prompt "Can you explain how to write an HTTP server in Rust?"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan infer Hive.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Infer Hive berhasil dijalankan.${NC}"
}

# Memeriksa multiplier dan poin Hive
check_hive_points() {
    echo -e "${BLUE}Memeriksa multiplier dan poin Hive...${NC}"
    docker exec -it aios-container /app/aios-cli hive points
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal memeriksa multiplier dan poin Hive.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Poin dan multiplier Hive berhasil diperiksa.${NC}"
}

# Langkah-langkah utama
check_and_install_docker
get_private_key
start_container
wait_for_container_to_start
start_daemon
view_available_models
install_local_model
run_infer
hive_login
run_hive_infer
check_hive_points

echo -e "${GREEN}Semua langkah berhasil dilakukan!${NC}"
