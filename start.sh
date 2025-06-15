#!/bin/bash

set -e
set -o pipefail

# === 0. System Update ===
sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y
sudo apt autoremove -y && sudo apt autoclean -y

# === 1. Install Go 1.22 ===
GO_VERSION=1.22.0
GO_TAR=go$GO_VERSION.linux-amd64.tar.gz
wget https://go.dev/dl/$GO_TAR
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf $GO_TAR
rm $GO_TAR

# === 1.1 Persist environment variables in ~/.bashrc ===
if ! grep -q 'export PATH=/usr/local/go/bin:$PATH' ~/.bashrc; then
  echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
fi

if ! grep -q 'export GOPATH=$HOME/go' ~/.bashrc; then
  echo 'export GOPATH=$HOME/go' >> ~/.bashrc
fi

if ! grep -q 'export GO111MODULE=off' ~/.bashrc; then
  echo 'export GO111MODULE=off' >> ~/.bashrc
fi

# === 1.2 Apply changes for current shell session ===
export PATH=/usr/local/go/bin:$PATH
export GOPATH=$HOME/go
export GO111MODULE=off

# === 2. Disable Go Modules (redundant if already in bashrc, but explicit) ===
go env -w GO111MODULE=off

# === 3. Install Required Packages ===
sudo apt-get update
sudo apt-get install -y \
  gcc cmake libssl-dev openssl libgmp-dev \
  bzip2 m4 build-essential git curl libc-dev \
  wget texinfo nodejs npm pcscd

# === 4. Install GMP 6.1.2 ===
wget https://ftp.gnu.org/gnu/gmp/gmp-6.1.2.tar.bz2
tar -xjf gmp-6.1.2.tar.bz2
cd gmp-6.1.2
./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.1.2
make
make check || echo "※ Some tests may fail and can be ignored."   
make html
sudo make install
sudo make install-html
cd ..
sudo cp -rf /usr/lib/libgmp* /usr/local/lib/

# === 5. Clone and Initialize Cypherium ===
mkdir -p "$GOPATH/src/github.com/cypherium"
cd "$GOPATH/src/github.com/cypherium"
git clone https://github.com/CypherTroopers/cypher.git
cd cypher
cp ./crypto/bls/lib/linux/* ./crypto/bls/lib/

# === 6. Clone Required Go Dependencies ===
echo "===> Fetching Go dependencies..."
declare -A repos=(
  [VictoriaMetrics/fastcache]=https://github.com/VictoriaMetrics/fastcache.git
  [shirou/gopsutil]=https://github.com/shirou/gopsutil.git
  [dlclark/regexp2]=https://github.com/dlclark/regexp2.git
  [go-sourcemap/sourcemap]=https://github.com/go-sourcemap/sourcemap.git
  [tklauser/go-sysconf]=https://github.com/tklauser/go-sysconf.git
  [tklauser/numcpus]=https://github.com/tklauser/numcpus.git
)
for path in "${!repos[@]}"; do
  repo_url="${repos[$path]}"
  full_path="$GOPATH/src/github.com/$path"
  mkdir -p "$(dirname "$full_path")"
  rm -rf "$full_path"
  git clone "$repo_url" "$full_path"
done

mkdir -p "$GOPATH/src/golang.org/x"
rm -rf "$GOPATH/src/golang.org/x/sys"
git clone https://go.googlesource.com/sys "$GOPATH/src/golang.org/x/sys"
echo "===> Dependency fetch complete"

# === 7. Build Cypherium ===
cd "$GOPATH/src/github.com/cypherium/cypher"
echo "===> Building Cypherium..."
make cypher

# === 8. Initialize genesis.json & Copy chaindata ===
echo "===> Initializing data directory..."
if [ ! -f ./genesis.json ]; then
  echo "❌ genesis.json not found. Please place it in the cypher directory."
  exit 1
fi
./build/bin/cypher --datadir chaindbname init ./genesis.json
git clone https://github.com/CypherTroopers/chaindata.git
cp -r ./chaindata/* ./chaindbname/cypher/chaindata/

# === 9. Stabilize Node.js & Install PM2 ===
sudo npm install -g n
sudo n stable
sudo apt purge -y nodejs npm
sudo apt autoremove -y
export PATH="/usr/local/bin:$PATH"
hash -r
npm install -g pm2

# === 10. Create start-cypher.sh ===
echo "===> Creating start-cypher.sh..."

cat << 'EOF' > "$GOPATH/src/github.com/cypherium/cypher/start-cypher.sh"
#!/bin/bash

./build/bin/cypher \
  --verbosity 4 \
  --rnetport 7100 \
  --syncmode full \
  --nat none \
  --ws \
  --ws.addr 0.0.0.0 \
  --ws.port 8546 \
  --ws.origins "*" \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8000 \
  --http.api eth,web3,net,miner,txpool,personal \
  --http.corsdomain "*" \
  --port 6000 \
  --miner.gastarget 3758096384 \
  --datadir chaindbname \
  --networkid 16166 \
  --gcmode archive \
  --allow-insecure-unlock \
  --mine \
  --bootnodes enode://046f15d710dfe708525b962372b125af83ddb2d95c239feb33cfbea1c336b48852d66fa382d88875eadb77c7b427b3cebe0bc302dbea801d382b65089fa396a5@61.29.244.68:6000,enode://9732dae6f5261efe54123911654586ed247baa03172e8b11ea26b43e0d63d0776e1bea965cec3ca8737af64ff7d488c74726ec5e3c580568b35e6f232e9d8519@61.29.244.66:6000,enode://b1d2b3d65a477840a8acf2aed5dc20990929079fa4fc9e41ff5070093459cde94cfcb79545c86d4b57e226d79864df6e061b7437a20554ffa0d0ebb76b51c307@61.29.244.32:6000,enode://512ded1da24f67ffb005a060e4d65e66cd4e228f06fed99771aa290deaa73322655e32554a2a7f3b04cc72851e6de6893d2b89f7d7a049522fb03d0dec0ab92d@61.29.244.76:35620,enode://9b12b657b2476152dc2df5dbbe87562dc71ad114e94b4f548f55adbf80762506d72ce847132f4504159331db6573b0088a910767290e6e6e2502e5a551cf4c1a@61.29.244.64:6000,enode://15f6e3d408aac2b5add4a384cd1111067d2a449bf054de35c0b73c0bd876f7954b44bfd9bf708f120f054a4135d3739251e20cc4747976505356d97c0ce112c6@61.29.244.48:6000,enode://32d7deca39008f42b03ef96a6b13b053616054c157cbb565c9472ab5d5a9f1ecedf59eafcbabcae7361713141ebddf1be5343b1b12e60a830bdd2d604b710327@61.29.244.13:6000,enode://38ee656b67c30e4feb3f49ce87e2809d4d3b69cf470371ba1c9309fb7804e5a052075d010b04671fe47e5aa59f0542dbcc35fa6c16622eb1644dde9f0202d955@61.29.244.75:6000,enode://b4c6c88b8a30963af1031ba39f68be183b156512ce2622a2e63141700cafa0bf5c9bb5e2daa244d9c08a7c14dceabff03747dfa5388e2393fbbfaf078f486118@61.29.244.67:6000,enode://9b7e86311fad81cd9b662d5859c5d5e758c034d0ba111162fe9ee98d2ee8dbc90b53276407e0f80245ee5ed0a403523797fe396a856ff06081e4ff12b6405be8@61.29.244.53:6000,enode://0d8103ab3470d58eee82f286295cb9da14f0343d519b874c22140a926fa3824c77f4fa951314f33ba585ab431c23ec0867804645840dc8696503e557ebf34977@61.29.244.77:6000,enode://d5764140149dc4f8e5b2f7dac41e0a826f65fcb4417e2f0fbbbfdcd59784ef58ac81a14250ad6301a5b9389159859b422dba4f6d456c72a2b492b3381c51198b@61.29.244.65:58814,enode://6f7936056a207e99dae0b6fc7211f7e014bd2a73a8e465a8773453a17b6c25cc46f2a4adb12e38a6a7932c0ac6acb4c2409c75a70cc316b1fe15708435b303cd@61.29.244.72:58004,enode://3773f29c45235a62e3a53859db3aaf2f2b33402bfb7bbe213f485a472d605bf7ebc6269920209dcdec4feecd82ea1d30f8870ebbb4b6308b916c6795fc950693@61.29.244.56:6000,enode://cb6a2bd39ce986b875d20f432c2dedb9c0f77179d5d1013c93ae8d0e3cc6188a66edcd647720c3c80b7607c1ad65a830b17b76e42f3fcbe21fa22fb4545185df@61.29.244.50:6000 \
  console
EOF

chmod +x "$GOPATH/src/github.com/cypherium/cypher/start-cypher.sh"
echo "✅ start-cypher.sh created successfully"

# === 11. Start with PM2 ===
cd "$GOPATH/src/github.com/cypherium/cypher"
pm2 start ./start-cypher.sh --name cypher-node
STARTUP_CMD=$(pm2 startup | grep sudo)
eval "$STARTUP_CMD"
pm2 save

# === 12. Completion Notice ===
echo "✅ Setup complete!"
echo "The Cypherium node is now running in the background managed by PM2."
echo "View logs: pm2 logs cypher-node"
echo "Check status: pm2 status"
echo "Restart: pm2 restart cypher-node"
echo "Restore after reboot: pm2 resurrect"
