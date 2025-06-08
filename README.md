## Node and Mining Setup Instructions

# 1. Install Required Package and Clone the Repository
sudo apt install git

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
```

