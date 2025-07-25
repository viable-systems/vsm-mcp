#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          EXECUTING BLOCKCHAIN TASK VIA DIRECT API              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# First, let's add blockchain capability mapping by restarting with env var
echo "STEP 1: Restarting API server with blockchain capability..."
pkill -f "mix run START_WEB_API.exs" || true
sleep 2

# Start with blockchain capability enabled
BLOCKCHAIN_CAPABILITY=true mix run START_WEB_API.exs > api_server_blockchain.log 2>&1 &
sleep 5

echo "STEP 2: Checking capabilities..."
curl -s http://localhost:4000/capabilities | python3 -m json.tool

echo -e "\nSTEP 3: Checking MCP servers..."
curl -s http://localhost:4000/mcp/servers | python3 -m json.tool | head -20

echo -e "\nSTEP 4: Executing actual blockchain task..."
echo "Generating vanity address with prefix '0xCAFE'..."
echo "(This may take 10-60 seconds depending on luck...)"

# Execute with longer timeout
curl -X POST http://localhost:4000/mcp/execute \
  -H "Content-Type: application/json" \
  -d '{
    "capability": "blockchain",
    "task": {
      "type": "vanity_address",
      "prefix": "0xCAFE",
      "caseSensitive": false
    }
  }' \
  -m 300 \
  -s | python3 -m json.tool

echo -e "\nDone!"