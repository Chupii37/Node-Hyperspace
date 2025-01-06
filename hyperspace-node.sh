#!/bin/bash

# Definisikan warna untuk output yang lebih mudah dibaca
CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # Tanpa warna (reset)

echo -e "${CYAN}SHOWING ANIANI!!!${NC}"

# Fungsi untuk menunggu input atau konfirmasi pengguna
wait_for_user() {
  read -p "Apakah Anda ingin melanjutkan? (yes/no): " answer
  if [[ "$answer" != "yes" ]]; then
    echo -e "${RED}❌ Proses dibatalkan.${NC}"
    exit 1
  fi
}

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
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Gagal memperbarui sistem.${NC}"
    exit 1
fi
echo -e "${GREEN}Sistem berhasil diperbarui.${NC}"

# Meminta input private key dan menyimpannya
get_private_key() {
  echo -e "${CYAN}Silakan masukkan private key...${NC}"
  read -p "Masukkan private key: " private_key
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

  container_running=$(docker ps -q -f name=aios-container)
  if [ -z "$container_running" ]; then
    echo -e "${BLUE}Menjalankan kontainer Docker kartikhyper/aios...${NC}"
    # Mengubah perintah docker run untuk memastikan kontainer tetap berjalan
    docker run -d --name aios-container -v /root:/root kartikhyper/aios /bin/bash -c "while true; do sleep 3600; done"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal menjalankan kontainer Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kontainer Docker berhasil dijalankan.${NC}"

    # Masuk ke dalam kontainer dan mulai daemon
    echo -e "${BLUE}Masuk ke dalam kontainer dan memulai daemon...${NC}"
    docker exec -it aios-container bash -c "
      echo 'Memulai daemon...'
      /app/aios-cli start
      /app/aios-cli models available
      /app/aios-cli models add hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf
    "

    # Menunggu konfirmasi pengguna untuk menjalankan infer
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

    # Menggunakan private key untuk login ke Hive
    /app/aios-cli hive import-keys ./my.pem
    /app/aios-cli hive login
    /app/aios-cli hive select-tier 4
    /app/aios-cli hive connect

    # Menunggu konfirmasi pengguna untuk menjalankan infer melalui Hive
    echo -e "${CYAN}Apakah Anda ingin menjalankan infer dengan Hive menggunakan model yang telah diinstal? (yes/no)${NC}"
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

    # Menambahkan langkah untuk memeriksa multiplier dan points
    echo -e "${BLUE}Memeriksa multiplier dan poin Hive...${NC}"
    docker exec -it aios-container /app/aios-cli hive points
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Gagal memeriksa multiplier dan poin Hive.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Poin dan multiplier Hive berhasil diperiksa.${NC}"
  fi
}

# Menjalankan fungsi-fungsi yang telah didefinisikan
check_and_install_docker
get_private_key
pull_and_run_docker

echo -e "${GREEN}Semua langkah berhasil dilakukan!${NC}"
