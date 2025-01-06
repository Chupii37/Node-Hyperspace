#!/bin/bash

# Definisikan warna untuk output yang lebih mudah dibaca
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'  # Tanpa warna (reset)

echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

# Fungsi untuk menunggu input atau konfirmasi pengguna
wait_for_user() {
  read -p "Tekan [Enter] untuk melanjutkan..."
}

# Mengunduh dan memeriksa Logo.sh
echo -e "${BLUE}📥 Mengunduh dan memeriksa Logo.sh...${NC}"
wget https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh -O Logo.sh
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal mengunduh Logo.sh.${NC}"
    exit 1
fi
cat Logo.sh  # Verifikasi konten skrip
wait_for_user  # Tunggu konfirmasi untuk melanjutkan
bash Logo.sh  # Menjalankan Logo.sh

# Update sistem
echo -e "${BLUE}Memastikan sistem sudah terupdate...${NC}"
apt update -y && apt upgrade -y
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal memperbarui sistem.${NC}"
    exit 1
fi
echo -e "${GREEN}Sistem berhasil diperbarui.${NC}"
wait_for_user

# Meminta input private key dan menyimpannya
get_private_key() {
  echo -e "${CYAN}Silakan masukkan private key...${NC}"
  read -p "Masukkan private key: " private_key

  # Menyimpan private key ke file my.pem dan atur hak akses
  echo -e "$private_key" > ./my.pem
  chmod 600 ./my.pem
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
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menginstal Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker berhasil diinstal dan dijalankan.${NC}"
  else
    echo -e "${GREEN}Docker sudah terinstal!${NC}"
  fi
  wait_for_user
}

# Menarik dan menjalankan kontainer Docker
pull_and_run_docker() {
  echo -e "${BLUE}Menarik image Docker kartikhyper/aios...${NC}"
  docker pull kartikhyper/aios
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal menarik image Docker.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Image Docker berhasil diunduh.${NC}"
  wait_for_user

  container_running=$(docker ps -q -f name=aios-container)
  if [ -z "$container_running" ]; then
    echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    docker run -d --restart unless-stopped --name aios-container -v /root:/root kartikhyper/aios bash -c "
      echo 'Memulai daemon...'
    
      # Start the actual daemon
      /app/aios-cli start

      # See what models are available
      /app/aios-cli models available

      # Install one of them locally
      /app/aios-cli models add hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf

      # Run a local inference using it
      /app/aios-cli infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt 'Can you explain how to write an HTTP server in Rust?'

      # Import your private key from a .pem or .base58 file
      /app/aios-cli hive import-keys ./my.pem

      # Set those keys as the preferred keys for this session
      /app/aios-cli hive login

      # Run this to see what models are required
      /app/aios-cli hive select-tier 4

      # Connect to the network (now providing inference for the model you installed before)
      /app/aios-cli hive connect

      # Run an inference through someone else on the network (as you can see it's the exact same format as the normal `infer` just prefixed with `hive`)
      /app/aios-cli hive infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt 'Can you explain how to write an HTTP server in Rust?'
    "
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan kontainer Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kontainer Docker berhasil dijalankan.${NC}"
  else
    echo -e "${GREEN}Kontainer Docker sudah berjalan.${NC}"
  fi
  wait_for_user
}

# Menjalankan fungsi-fungsi yang telah didefinisikan
check_and_install_docker
get_private_key
pull_and_run_docker

echo -e "${GREEN}Semua langkah berhasil dilakukan!${NC}"
