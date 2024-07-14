#!/bin/bash
#Node version is not used - executiuon via release_autorun 
#Comment out for automatic creation of the node version
#NODE_VERSION=1.4.21

#Comment out for automatic creation of the qclient version
#QCLIENT_VERSION=1.4.19.1

# Step 0: Welcome
echo "This script is made with ❤️ by 0xOzgur.eth @ https://quilibrium.space"
echo "⏳Enjoy and sit back while you are upgrading your Quilibrium Node to v$VERSION!"
echo "The script is prepared for Ubuntu machines. If you are using another operating system, please check the compatibility of the script."
echo "⏳Processing..."
sleep 5  # Add a 5-second delay

#==========================
# CREATE PATH VARIABLES
#==========================

# Determine the ExecStart line based on the architecture
ARCH=$(uname -m)
OS=$(uname -s)

# Determine node latest version
# Check if NODE_VERSION is empty
if [ -z "$NODE_VERSION" ]; then
    NODE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | sort -V | tail -n 1)
    echo "✅ Automatically determined NODE_VERSION: $NODE_VERSION"
else
    echo "✅ Using specified NODE_VERSION: $NODE_VERSION"
fi

# Determine qclient latest version
if [ -z "$QCLIENT_VERSION" ]; then
    QCLIENT_VERSION=$(curl -s https://releases.quilibrium.com/qclient-release | grep -E "^qclient-[0-9]+(\.[0-9]+)*" | sed 's/^qclient-//' | cut -d '-' -f 1 | sort -V | tail -n 1)
    echo "✅ Automatically determined QCLIENT_VERSION: $QCLIENT_VERSION"
else
    echo "✅ Using specified QCLIENT_VERSION: $QCLIENT_VERSION"
fi

echo

# Determine the node binary name based on the architecture and OS
if [ "$ARCH" = "x86_64" ]; then
    if [ "$OS" = "Linux" ]; then
        NODE_BINARY="node-$NODE_VERSION-linux-amd64"
        GO_BINARY="go1.22.4.linux-amd64.tar.gz"
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-amd64"
    elif [ "$OS" = "Darwin" ]; then
        NODE_BINARY="node-$NODE_VERSION-darwin-amd64"
        GO_BINARY="go1.22.4.darwin-amd64.tar.gz"
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-arm64"
    fi
elif [ "$ARCH" = "aarch64" ]; then
    if [ "$OS" = "Linux" ]; then
        NODE_BINARY="node-$NODE_VERSION-linux-arm64"
        GO_BINARY="go1.22.4.linux-arm64.tar.gz"
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-linux-arm64"
    elif [ "$OS" = "Darwin" ]; then
        NODE_BINARY="node-$NODE_VERSION-darwin-arm64"
        GO_BINARY="go1.22.4.darwin-arm64.tar.gz"
        QCLIENT_BINARY="qclient-$QCLIENT_VERSION-darwin-arm64"
    fi
fi

#==========================
# NODE UPDATE
#==========================

# Stop the ceremonyclient service
    echo "Updating node..."
    service ceremonyclient stop

# apt install cpulimit -y
# apt install gawk -y #incase it is not installed

# Download Binary
echo "⏳ Downloading New Release v$NODE_VERSION"
cd  ~/ceremonyclient
git remote set-url origin https://github.com/QuilibriumNetwork/ceremonyclient.git
git checkout main
git branch -D release
git pull
git checkout release

#==========================
# QCLIENT UPDATE
#==========================

# Step 4:Update qClient
echo "Updating qClient"
sleep 1  # Add a 1-second delay
cd ~/ceremonyclient/client
rm -f qclient
wget https://releases.quilibrium.com/$QCLIENT_BINARY
mv $QCLIENT_BINARY qclient
chmod +x qclient

# Get the current user's home directory
HOME=$(eval echo ~$HOME_DIR)

# Use the home directory in the path
NODE_PATH="$HOME/ceremonyclient/node"
EXEC_START="$NODE_PATH/release_autorun.sh"

#==========================
# SERVICE UPDATE
#==========================

# Re-Create Ceremonyclient Service
echo "⏳ Re-Creating Ceremonyclient Service"
sleep 2  # Add a 2-second delay
SERVICE_FILE="/lib/systemd/system/ceremonyclient.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "📝 Creating new ceremonyclient service file..."
    if ! sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=$NODE_PATH
ExecStart=$EXEC_START

[Install]
WantedBy=multi-user.target
EOF
    then
        echo "❌ Error: Failed to create ceremonyclient service file." >&2
        exit 1
    fi
else
    echo "🔍 Checking existing ceremonyclient service file..."
    # Check if the required lines exist and if they are different
    if ! grep -q "WorkingDirectory=$NODE_PATH" "$SERVICE_FILE" || ! grep -q "ExecStart=$EXEC_START" "$SERVICE_FILE"; then
        echo "🔄 Updating existing ceremonyclient service file..."
        # Replace the existing lines with new values
        sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$NODE_PATH|" "$SERVICE_FILE"
        sudo sed -i "s|ExecStart=.*|ExecStart=$EXEC_START|" "$SERVICE_FILE"
    else
        echo "✅ No changes needed."
    fi
fi

# Start the ceremonyclient service
echo "✅ Starting Ceremonyclient Service"
sleep 2  # Add a 2-second delay
sudo systemctl daemon-reload
sudo systemctl enable ceremonyclient
sudo service ceremonyclient start

# See the logs of the ceremonyclient service
echo "🎉 Welcome to Quilibrium Ceremonyclient v$NODE_VERSION"
echo "⏳ Please let it flow node logs at least 5 minutes then you can press CTRL + C to exit the logs."
sleep 5  # Add a 5-second delay
sudo journalctl -u ceremonyclient.service -f --no-hostname -o cat
