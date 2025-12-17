#!/bin/bash
set -e

echo "=========================================="
echo "DynamoDB Local Setup Script for Debian"
echo "=========================================="

# Update package list
echo "Updating package lists..."
apt-get update

# Install Java (required for DynamoDB Local)
echo "Installing Java..."
apt-get install -y openjdk-11-jre-headless wget unzip curl

# Install AWS CLI (for table management)
echo "Installing AWS CLI..."
apt-get install -y awscli

# Create directory for DynamoDB Local
DYNAMODB_DIR="/opt/dynamodb-local"
mkdir -p "$DYNAMODB_DIR"
cd "$DYNAMODB_DIR"

# Download DynamoDB Local
echo "Downloading DynamoDB Local..."
DYNAMODB_VERSION="latest"
wget -q https://s3.us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz

# Extract DynamoDB Local
echo "Extracting DynamoDB Local..."
tar -xzf dynamodb_local_latest.tar.gz
rm dynamodb_local_latest.tar.gz

# Create data directory for persistence
mkdir -p "$DYNAMODB_DIR/data"

# Create systemd service file (optional)
echo "Creating systemd service file..."
cat > /etc/systemd/system/dynamodb-local.service <<EOF
[Unit]
Description=DynamoDB Local
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DYNAMODB_DIR
ExecStart=/usr/bin/java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb -dbPath ./data -port 8000
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create convenience start script
cat > "$DYNAMODB_DIR/start.sh" <<'EOF'
#!/bin/bash
cd /opt/dynamodb-local
echo "Starting DynamoDB Local on port 8000..."
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb -dbPath ./data -port 8000
EOF

chmod +x "$DYNAMODB_DIR/start.sh"

# Create convenience stop script
cat > "$DYNAMODB_DIR/stop.sh" <<'EOF'
#!/bin/bash
echo "Stopping DynamoDB Local..."
pkill -f DynamoDBLocal.jar
echo "DynamoDB Local stopped."
EOF

chmod +x "$DYNAMODB_DIR/stop.sh"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "To start DynamoDB Local:"
echo "  Option 1: $DYNAMODB_DIR/start.sh"
echo "  Option 2: systemctl start dynamodb-local"
echo "  Option 3: cd $DYNAMODB_DIR && java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb -port 8000"
echo ""
echo "To enable auto-start on boot:"
echo "  systemctl enable dynamodb-local"
echo ""
echo "To stop DynamoDB Local:"
echo "  $DYNAMODB_DIR/stop.sh"
echo "  or: systemctl stop dynamodb-local"
echo ""
echo "DynamoDB Local will be accessible at: http://localhost:8000"
echo ""
echo "Next steps:"
echo "  1. Start DynamoDB Local"
echo "  2. Run the init-table.sh script to create the url_mappings table"
echo ""
