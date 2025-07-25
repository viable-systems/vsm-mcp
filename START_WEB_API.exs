#!/usr/bin/env elixir

# Start HTTPoison
Application.ensure_all_started(:httpoison)

# Start the app
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║         VSM-MCP AUTONOMOUS API STARTED ON PORT 4000        ║
╚═══════════════════════════════════════════════════════════╝

API ENDPOINTS:

GET  /health        - System health check
GET  /capabilities  - Current capabilities  
GET  /daemon        - Daemon status
POST /variety-gap   - Inject variety gap (triggers autonomy!)
POST /autonomy/trigger - Force autonomous action

EXAMPLE COMMANDS:

# Check health
curl http://localhost:4000/health

# See current capabilities
curl http://localhost:4000/capabilities

# TRIGGER AUTONOMOUS ACTION!
curl -X POST http://localhost:4000/autonomy/trigger \\
  -H "Content-Type: application/json" \\
  -d '{"capabilities": ["database", "api"]}'

The system will AUTONOMOUSLY:
1. Detect the variety gap
2. Search for MCP servers
3. Install them
4. Integrate capabilities

NO SCRIPTS. NO MOCKS. REAL AUTONOMY VIA HTTP!
"""

# Keep running
Process.sleep(:infinity)