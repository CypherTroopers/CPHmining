 sudo apt install git
 
 git clone https://github.com/CypherTroopers/CPHmining.git
 
 cd CPHmining

./start.sh

Once you run ./start.sh, everything needed will be installed through the all-in-one package, the node will start running, and synchronization will begin.
You can check the synchronization status with the following command:

pm2 logs


Next, let's configure mining.

cd ..

cd go/src/github.com/cypherium/cypher

./build/bin/cypher attach ipc:/root/go/src/github.com/cypherium/cypher/chaindbname/cypher.ipc

Once you're in the console using the command above, check whether the synchronization has completed.

If eth.syncing returns false, it means the synchronization is complete.　
