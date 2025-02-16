#!/bin/bash

# Display message with cyan color
echo -e "\033[36mShowing ANIANI!!!\033[0m"

# Display logo directly from URL without saving
echo -e "\033[32mDisplaying logo...\033[0m"
wget -qO- https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh | bash
if [ $? -ne 0 ]; then
  echo -e "\033[31mFailed to display logo.\033[0m"
  exit 1
fi

# Check for updates and upgrade if any
echo -e "\033[33mChecking for system updates...\033[0m"
sudo apt update && sudo apt upgrade -y

# Preparing private key
echo -e "\033[32mPreparing private key...\033[0m"
read -p "Enter your private key: " private_key
echo -e "$private_key" > /root/my.pem
chmod 600 /root/my.pem

# Check Docker installation, install if not installed
if ! command -v docker &> /dev/null; then
    echo -e "\033[33mDocker not found. Installing Docker...\033[0m"
    sudo apt install -y docker.io
    if [ $? -ne 0 ]; then
        echo -e "\033[31mFailed to install Docker.\033[0m"
        exit 1
    fi
else
    echo -e "\033[32mDocker is already installed.\033[0m"
fi

# Pull the Docker image
echo -e "\033[32mPulling the Docker image...\033[0m"
docker pull kartikhyper/aios
if [ $? -ne 0 ]; then
    echo -e "\033[31mFailed to pull Docker image.\033[0m"
    exit 1
fi

# Run the Docker container
echo -e "\033[32mRunning Docker container...\033[0m"
docker run -d --name aios-container --restart unless-stopped -v /root:/root kartikhyper/aios /app/aios-cli start
if [ $? -ne 0 ]; then
    echo -e "\033[31mFailed to start the Docker container.\033[0m"
    exit 1
fi

# Import private key into Docker container
echo -e "\033[32mImporting private key...\033[0m"
docker exec -it aios-container /app/aios-cli hive import-keys /root/my.pem

# Login to Hive
echo -e "\033[32mLogging in to Hive...\033[0m"
docker exec -it aios-container /app/aios-cli hive login

# Select tier 3
echo -e "\033[32mSelecting tier 3...\033[0m"
docker exec -it aios-container /app/aios-cli hive select-tier 3

# Add the model
echo -e "\033[32mAdding the model...\033[0m"
docker exec -it aios-container /app/aios-cli models add hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf

# Connect to Hive
echo -e "\033[32mConnecting to Hive...\033[0m"
docker exec -it aios-container /app/aios-cli hive connect

# Select tier 3 again after adding the model and connecting
echo -e "\033[32mSelecting tier 3 again...\033[0m"
docker exec -it aios-container /app/aios-cli hive select-tier 3

# Check Hive points
echo -e "\033[32mChecking Hive points...\033[0m"
docker exec -it aios-container /app/aios-cli hive points

# Display whoami info
echo -e "\033[32mDisplaying Hive user info...\033[0m"
docker exec -it aios-container /app/aios-cli hive whoami
