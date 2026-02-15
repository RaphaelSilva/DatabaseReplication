#!/bin/bash
# Example: How to run the replication test

echo "==================================================================="
echo "Database Replication Test - Quick Start Guide"
echo "==================================================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file with database credentials:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your values"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$PRIMARY_IP" ] || [ -z "$REPLICA_1_IP" ]; then
    echo "❌ Error: Required environment variables not set!"
    echo "Please ensure .env contains:"
    echo "  - POSTGRES_PASSWORD"
    echo "  - PRIMARY_IP"
    echo "  - REPLICA_1_IP"
    exit 1
fi

echo "✓ Environment variables loaded"
echo "  Primary: $PRIMARY_IP"
echo "  Replica 1: $REPLICA_1_IP"
if [ -n "$REPLICA_2_IP" ]; then
    echo "  Replica 2: $REPLICA_2_IP"
fi
echo ""

# Check uv installation
echo "Checking uv installation..."
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
else
    echo "✓ uv already installed"
fi

# Install dependencies if needed
echo "Syncing dependencies..."
cd src
uv sync
cd ..
echo "✓ Dependencies synced"
echo ""

# Show available test options
echo "==================================================================="
echo "Test Options:"
echo "==================================================================="
echo ""
echo "1. Quick test (1000 writes, 1000 reads):"
echo "   ./scripts/run.sh test_replication"
echo ""
echo "2. Custom operations:"
echo "   ./scripts/run.sh test_replication --writes 5000 --reads 10000"
echo ""
echo "3. Adjust replication wait time:"
echo "   ./scripts/run.sh test_replication --wait 5"
echo ""
echo "4. All options combined:"
echo "   ./scripts/run.sh test_replication --writes 2000 --reads 5000 --wait 3"
echo ""
echo "==================================================================="
echo ""

# Ask user which test to run
read -p "Run quick test now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting quick test..."
    ./scripts/run.sh test_replication
fi
