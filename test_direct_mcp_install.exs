#!/usr/bin/env elixir
# Direct test of MCP server discovery and installation

Mix.install([
  {:vsm_mcp, path: "."},
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.4"}
])

require Logger

Logger.info("🚀 Direct MCP Server Discovery and Installation Test")

# Start required services
{:ok, _} = Application.ensure_all_started(:httpoison)
{:ok, _} = VsmMcp.Core.MCPDiscovery.start_link()

# Wait for initialization
Process.sleep(1000)

Logger.info("\n1️⃣ Testing capability mapping...")
capabilities = ["filesystem", "memory", "database"]

Enum.each(capabilities, fn cap ->
  packages = VsmMcp.Core.CapabilityMapping.map_capability_to_packages(cap)
  Logger.info("   #{cap} -> #{inspect(packages)}")
end)

Logger.info("\n2️⃣ Discovering real MCP servers...")
case VsmMcp.Core.MCPDiscovery.discover_servers(["filesystem"]) do
  {:ok, servers} ->
    Logger.info("   Found #{length(servers)} servers")
    
    if length(servers) > 0 do
      server = List.first(servers)
      Logger.info("   First server: #{server.name} v#{server.version}")
      
      Logger.info("\n3️⃣ Installing #{server.name}...")
      
      case VsmMcp.Core.MCPDiscovery.install_mcp_server(server) do
        {:ok, installation} ->
          Logger.info("   ✅ Installation successful!")
          Logger.info("   Path: #{installation.path}")
          
          # Verify installation
          if File.exists?(installation.path) do
            Logger.info("   ✅ Installation directory exists")
            
            files = File.ls!(installation.path)
            Logger.info("   Files: #{inspect(files)}")
          end
          
        {:error, reason} ->
          Logger.error("   ❌ Installation failed: #{inspect(reason)}")
      end
    else
      Logger.error("   ❌ No servers found!")
    end
    
  {:error, reason} ->
    Logger.error("   ❌ Discovery failed: #{inspect(reason)}")
end

Logger.info("\n✨ Test complete!")