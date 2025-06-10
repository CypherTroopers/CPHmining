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

# Set Go PATH (persist in ~/.bashrc)
if ! grep -q 'export PATH=/usr/local/go/bin:$PATH' ~/.bashrc; then
  echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
  echo 'export GOPATH=$HOME/go' >> ~/.bashrc
fi
export PATH=/usr/local/go/bin:$PATH
export GOPATH=$HOME/go

# === 2. Disable Go Modules ===
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
  --bootnodes enode://a37941b709d0c6138704ee961c495cddbf6e92a09e85f88ddef977619b3d8e054197e9b89ef83891698668c5bdcbec6deeec1951bf41f65800c8285a7ea047fe@5.180.149.109:30303 \
  console
EOF

chmod +x "$GOPATH/src/github.com/cypherium/cypher/start-cypher.sh"
echo "✅ start-cypher.sh created successfully"

# === 11. Start with PM2 ===
cd "$GOPATH/src/github.com/cypherium/cypher"
pm2 start ./start-cypher.sh --name cypher-node
pm2 save

# === 12. Completion Notice ===
echo "✅ Setup complete!"
echo "The Cypherium node is now running in the background managed by PM2."
echo "View logs: pm2 logs cypher-node"
echo "Check status: pm2 status"
echo "Restart: pm2 restart cypher-node"
echo "Restore after reboot: pm2 resurrect"
