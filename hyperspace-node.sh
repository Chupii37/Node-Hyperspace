#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RESET='\033[0m'

LOG_FILE="/root/script_progress.log"

log_message() {
    echo -e "$1"
    echo "$(date): $1" >> $LOG_FILE
}

retry() {
    local n=1
    local max=5
    local delay=10
    while true; do
        "$@" && return 0
        if (( n == max )); then
            return 1
        else
            log_message "Attempt $n/$max failed! Retrying in $delay seconds..."
            sleep $delay
        fi
        ((n++))
    done
}

display_logo() {
    log_message "${GREEN}Displaying logo...${RESET}"
    wget -qO- https://raw.githubusercontent.com/Chupii37/Chupii-Node/refs/heads/main/Logo.sh | bash || handle_error "Failed to fetch the logo script."
}

handle_error() {
    log_message "$1"
    exit 1
}

get_private_key() {
    log_message "${CYAN}Preparing private key...${RESET}"
    read -p "Enter your private key: " private_key
    echo -e "$private_key" > /root/my.pem
    chmod 600 /root/my.pem
    log_message "${GREEN}Private key saved as my.pem with proper permissions.${RESET}"
}

check_and_install_docker() {
    if ! command -v docker &> /dev/null; then
        log_message "${RED}Docker not found. Installing Docker...${RESET}"
        retry apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - 
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        retry apt update -y
        retry apt install -y docker-ce
        systemctl start docker
        systemctl enable docker
        log_message "${GREEN}Docker installed and started.${RESET}"
    else
        log_message "${GREEN}Docker is already installed.${RESET}"
    fi
}

start_container() {
    log_message "${BLUE}Starting Docker container...${RESET}"
    retry docker run -d --name aios-container --restart unless-stopped -v /root:/root kartikhyper/aios /app/aios-cli start
    log_message "${GREEN}Docker container started.${RESET}"
}

wait_for_container_to_start() {
    log_message "${CYAN}Waiting for container to initialize...${RESET}"
    sleep 60
}

check_daemon_status() {
    log_message "${BLUE}Checking daemon status inside the container...${RESET}"
    docker exec -it aios-container /app/aios-cli status
    if [[ $? -ne 0 ]]; then
        log_message "${RED}Daemon is not running, restarting...${RESET}"
        docker exec -it aios-container /app/aios-cli kill
        sleep 2
        docker exec -it aios-container /app/aios-cli start
        log_message "${GREEN}Daemon restarted.${RESET}"
    else
        log_message "${GREEN}Daemon is running.${RESET}"
    fi
}

install_local_model() {
    log_message "${BLUE}Installing local model...${RESET}"
    docker exec -it aios-container /app/aios-cli models add hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf
}

run_infer() {
    log_message "${BLUE}Running inference...${RESET}"
    retry docker exec -it aios-container /app/aios-cli infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt "What is 'Artificial Intelligence'?"
    log_message "${GREEN}Inference completed successfully.${RESET}"
}

hive_login() {
    log_message "${CYAN}Logging into Hive...${RESET}"
    docker exec -it aios-container /app/aios-cli hive import-keys /root/my.pem
    docker exec -it aios-container /app/aios-cli hive login
    docker exec -it aios-container /app/aios-cli hive connect
    log_message "${GREEN}Hive login successful.${RESET}"
}

run_hive_infer() {
    log_message "${BLUE}Running Hive inference...${RESET}"
    retry docker exec -it aios-container /app/aios-cli hive infer --model hf:TheBloke/Mistral-7B-Instruct-v0.1-GGUF:mistral-7b-instruct-v0.1.Q4_K_S.gguf --prompt "Explain what a server is in simple terms."
    log_message "${GREEN}Hive inference completed successfully.${RESET}"
}

check_hive_points() {
    log_message "${BLUE}Checking Hive points...${RESET}"
    docker exec -it aios-container /app/aios-cli hive points
    log_message "${GREEN}Hive points checked successfully.${RESET}"
}

get_current_signed_in_keys() {
    log_message "${BLUE}Getting currently signed-in keys...${RESET}"
    docker exec -it aios-container /app/aios-cli hive whoami
}

cleanup_package_lists() {
    log_message "${BLUE}Cleaning up package lists...${RESET}"
    sudo rm -rf /var/lib/apt/lists/*
}

# Main script flow
display_logo
check_and_install_docker
get_private_key
start_container
wait_for_container_to_start
check_daemon_status
install_local_model
run_infer
hive_login
run_hive_infer
check_hive_points
get_current_signed_in_keys
cleanup_package_lists

log_message "${GREEN}All steps completed successfully!${RESET}"

# Repeat every 1 hour
while true; do
    log_message "${CYAN}Restarting process every 1 hour...${RESET}"

    docker exec -it aios-container /app/aios-cli kill
    
    docker exec -it aios-container /app/aios-cli status
    if [[ $? -ne 0 ]]; then
        log_message "${RED}Daemon failed to start. Retrying...${RESET}"
    else
        log_message "${GREEN}Daemon is running and status has been checked.${RESET}"
    fi
    
    run_infer
    
    docker exec -it aios-container /app/aios-cli hive login
    docker exec -it aios-container /app/aios-cli hive connect

    run_hive_infer

    log_message "${GREEN}Cycle complete. Waiting 1 hour...${RESET}"
    sleep 3600  
    sleep 5  
done &
