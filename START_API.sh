#!/bin/bash
echo "Starting VSM-MCP API Server on port 4000..."
mix compile
exec mix run --no-halt