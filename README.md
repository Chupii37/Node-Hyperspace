#  Hyperspace Node

## System Requirements

Spek minimum :
4GB 2vCPU

Recommended :
8GB 4vCPU

## Register

Go to Hyperspace Node web site https://node.hyper.space then copy and save private key

## Installation

Run With Docker
```bash
   curl -O https://raw.githubusercontent.com/Chupii37/Node-Hyperspace/refs/heads/main/hyperspace-node.sh && chmod +x hyperspace-node.sh && ./hyperspace-node.sh
```
➖Just enter your private key

➖Done 

## After End Of Project
Stop the Docker Container
```bash
docker stop aios-container
 ```

Remove the Docker Container
```bash
docker rm aios-container
 ```

Remove the Docker Image
```bash
docker rmi kartikhyper/aios
 ```
