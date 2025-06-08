## Node and Mining Setup All In One Pack Instructions(for linux)

# 1. Install Required Package and Clone the Repository
sudo apt install git -y

git clone https://github.com/CypherTroopers/CPHmining.git

# 2. Navigate to the Directory and Start the Node
cd CPHmining

./start.sh
# Running ./start.sh will install all necessary dependencies via the all-in-one package,start the node, and begin synchronization.

# 3. Check Synchronization Status
pm2 logs
# This command allows you to monitor the synchronization progress.

# 4. Navigate to the Source Code Directory
cd ..

cd go/src/github.com/cypherium/cypher

# 5. Attach to the Console
./build/bin/cypher attach ipc:/root/go/src/github.com/cypherium/cypher/chaindbname/cypher.ipc

# 6. Check Synchronization Completion
eth.syncing
# If the command returns false, it means the synchronization is complete.

# === Account Creation and Mining Configuration ===

# After synchronization is complete, create two accounts:
# - One for mining
# - One for receiving mining rewards

# 7. Create mining account (Ed25519)
personal.newAccountEd25519("your_password")

# 8. Create reward-receiving account (ECDSA)
personal.newAccount("your_password")

# ⚠️ Make sure to save both wallet addresses.
# ⚠️ Do not forget the password—you will need it again later.

# 9. Exit the console before restarting the node
# (Use the following key combination)
CTRL+C

# 10. Restart the node with PM2
pm2 restart all

# 11. Reattach to the console
./build/bin/cypher attach ipc:/root/go/src/github.com/cypherium/cypher/chaindbname/cypher.ipc

# 12. Unlock both accounts
personal.unlockAccount("0xYourMiningAccountAddress", "your_password")

personal.unlockAccount("0xYourRewardAccountAddress", "your_password")

# 13. Set the reward-receiving address (Etherbase)
miner.setEtherbase("0xYourRewardAccountAddress")

# 14. Start mining using the mining account
miner.start(1, "0xYourMiningAccountAddress", "your_password")



＊＊＊＊＊＊＊＊＊＊Node Update Procedure＊＊＊＊＊＊＊＊＊

# If the official team releases a node update, you will need to update your node as well.

# 15. Stop the node before updating
cd go/src/github.com/cypherium/cypher

pm2 stop all

# 16. Pull the latest version and rebuild
git pull origin main

make clean

# 17. Restart the node
pm2 restart all

# The update is now complete.

# 18. Reattach to the console and check if mining is still running
./build/bin/cypher attach ipc:/root/go/src/github.com/cypherium/cypher/chaindbname/cypher.ipc

# 19. Check mining status
miner.status()

# If it shows "STOP", restart mining with the following command:
miner.start(1, "0xYourMiningAccountAddress", "your_password")
