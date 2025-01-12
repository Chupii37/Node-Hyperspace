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

➖If you have seen a comment : "Cycle complete. Waiting 1 hour..."

Press CTRL + C

➖Done 

## Useful commands
Check Log
```bash
docker logs -f aios-container
 ```

Check Point
```bash
docker exec -it aios-container /app/aios-cli hive points
 ```
Check Private Key
```bash
docker exec -it aios-container /app/aios-cli hive whoami
 ```

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
Remove Folder
```bash
sudo rm -rf /root/.cache/hyperspace/
```

```bash
sudo rm -rf /root/.config/hyperspace/
```
