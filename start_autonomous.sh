#!/bin/bash

# VSM-MCP Autonomous System Startup Script

echo "======================================="
echo "Starting VSM-MCP Autonomous System"
echo "======================================="
echo ""

# Check if Elixir is installed
if ! command -v elixir &> /dev/null; then
    echo "Error: Elixir is not installed. Please install Elixir first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo "Error: Not in VSM-MCP directory. Please run from project root."
    exit 1
fi

# Install dependencies if needed
if [ ! -d "deps" ]; then
    echo "Installing dependencies..."
    mix deps.get
fi

# Compile the project
echo "Compiling VSM-MCP..."
mix compile

# Start based on argument
case "$1" in
    "demo")
        echo "Running full autonomous demo..."
        mix run examples/full_autonomous_demo.exs
        ;;
    "simple")
        echo "Running simple demo..."
        mix run examples/simple_demo.exs
        ;;
    "mcp")
        echo "Running MCP AI integration demo..."
        mix run examples/mcp_ai_integration.exs
        ;;
    "server")
        echo "Starting MCP server mode..."
        echo "MCP server will listen on STDIO. Use Ctrl+C to exit."
        mix run --no-halt
        ;;
    "iex")
        echo "Starting interactive shell..."
        iex -S mix
        ;;
    *)
        echo "Usage: $0 {demo|simple|mcp|server|iex}"
        echo ""
        echo "Options:"
        echo "  demo   - Run full autonomous system demo"
        echo "  simple - Run simple demo"
        echo "  mcp    - Run MCP AI integration demo"
        echo "  server - Start as MCP server (STDIO)"
        echo "  iex    - Start interactive Elixir shell"
        echo ""
        echo "Example: $0 demo"
        exit 1
        ;;
esac