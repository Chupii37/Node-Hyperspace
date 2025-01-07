#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # Reset

# Menunggu konfirmasi dari pengguna untuk melanjutkan
wait_for_user() {
  read -p "Apakah Anda ingin melanjutkan? (yes/no): " answer
  if [[ "$answer" != "yes" ]]; then
    echo -e "${RED}❌ Proses dibatalkan.${NC}"
    exit 1
  fi
}

# Memastikan sistem sudah terupdate
echo -e "${BLUE}Memastikan sistem sudah terupdate...${NC}"
apt update -y && apt upgrade -y
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal memperbarui sistem.${NC}"
    exit 1
fi
echo -e "${GREEN}Sistem berhasil diperbarui.${NC}"

# Menunggu konfirmasi dari pengguna untuk melanjutkan
wait_for_user

# Menampilkan Logo.sh
echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
    exit 1
fi
cat Logo.sh
bash Logo.sh

get_private_key() {
  echo -e "${CYAN}Silakan masukkan private key...${NC}"
  read -s -p "Masukkan private key: " private_key
  echo -e "\n"
  echo -e "$private_key" > /root/my.pem
  chmod 600 /root/my.pem
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

# Memulai kontainer Docker
start_container() {
    echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    docker run -d --name aios-container -v /root:/root kartikhyper/aios /app/aios-cli start
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan kontainer.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kontainer berhasil dijalankan.${NC}"
}

# Menunggu kontainer dan daemon berjalan
wait_for_container_to_start() {
    echo -e "${CYAN}Menunggu kontainer Docker untuk memulai (60 detik)...${NC}"
    sleep 60  # Tunggu 1 menit untuk kontainer memulai daemon
}

# Memastikan daemon berjalan dengan benar
check_daemon_status() {
    echo -e "${BLUE}Memeriksa status daemon di dalam kontainer...${NC}"
    docker exec -it aios-container /app/aios-cli status
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Daemon tidak berjalan, mencoba untuk memulai ulang...${NC}"
        docker exec -it aios-container /app/aios-cli kill
        sleep 2
        docker exec -it aios-container /app/aios-cli start
        echo -e "${GREEN}Daemon berhasil dimulai ulang.${NC}"
    else
        echo -e "${GREEN}Daemon sudah berjalan.${NC}"
    fi
}

# Menginstal model lokal
install_local_model() {
    echo -e "${BLUE}Menginstal model lokal...${NC}"
    docker exec -it aios-container /app/aios-cli models add hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf
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
    docker exec -it aios-container /app/aios-cli infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt "Can you explain how to write an HTTP server in Rust?"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan infer.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Infer berhasil dijalankan.${NC}"
}

# Menggunakan private key untuk login ke Hive
hive_login() {
    docker exec -it aios-container /app/aios-cli hive import-keys /root/my.pem
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
    docker exec -it aios-container /app/aios-cli hive infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt "Can you explain how to write an HTTP server in Rust?"
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

# Mendapatkan kunci yang sedang login saat ini di Hive
get_current_signed_in_keys() {
    echo -e "${BLUE}Mendapatkan kunci yang sedang login saat ini...${NC}"
    docker exec -it aios-container /app/aios-cli hive whoami
}

# Langkah-langkah utama
check_and_install_docker
get_private_key
start_container
wait_for_container_to_start
check_daemon_status
install_local_model
check_installed_model  # Added after installing model
run_infer
hive_login
run_hive_infer
check_hive_points
get_current_signed_in_keys

echo -e "${GREEN}Semua langkah berhasil dilakukan!${NC}"
