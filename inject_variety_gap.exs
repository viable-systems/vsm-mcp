#!/usr/bin/env elixir
# Script to inject a variety gap and trigger real MCP server installation

Mix.install([
  {:vsm_mcp, path: "."}
])

require Logger

defmodule InjectVarietyGap do
  def run do
    Logger.info("🚀 Starting VSM-MCP with variety gap injection")
    
    # Start the application
    {:ok, _} = Application.ensure_all_started(:vsm_mcp)
    
    # Give the system time to initialize
    Process.sleep(2000)
    
    Logger.info("\n📊 Current System Status:")
    show_current_variety()
    
    Logger.info("\n💉 Injecting variety gap by simulating high environmental demands...")
    inject_gap()
    
    Logger.info("\n⏳ Waiting for autonomous response...")
    Process.sleep(5000)
    
    Logger.info("\n📋 Checking installed MCP servers:")
    check_installed_servers()
    
    Logger.info("\n✅ Test complete!")
  end
  
  defp show_current_variety do
    case VsmMcp.Integration.calculate_variety() do
      {:ok, variety} ->
        Logger.info("  Operational Variety: #{Float.round(variety.operational_variety, 2)}")
        Logger.info("  Environmental Variety: #{Float.round(variety.environmental_variety, 2)}")
        Logger.info("  Gap: #{Float.round(variety.gap, 2)}")
        Logger.info("  Ratio: #{Float.round(variety.ratio, 3)}")
      _ ->
        Logger.error("  Failed to calculate variety")
    end
  end
  
  defp inject_gap do
    # We'll use the daemon mode's internal message to simulate a variety gap
    # First, let's check if daemon is running
    case Process.whereis(VsmMcp.DaemonMode) do
      nil ->
        Logger.error("  ❌ Daemon mode not running. Starting it...")
        {:ok, _} = VsmMcp.DaemonMode.start_link()
        Process.sleep(1000)
        
      pid ->
        Logger.info("  ✅ Daemon mode running at #{inspect(pid)}")
    end
    
    # Send a check variety message to trigger the gap detection
    if pid = Process.whereis(VsmMcp.DaemonMode) do
      send(pid, :check_variety)
      Logger.info("  📨 Sent variety check trigger")
    end
  end
  
  defp check_installed_servers do
    case VsmMcp.Core.MCPDiscovery.list_installed_servers() do
      {:ok, servers} when map_size(servers) > 0 ->
        Logger.info("  ✅ Found #{map_size(servers)} installed MCP servers:")
        
        Enum.each(servers, fn {name, info} ->
          Logger.info("    📦 #{name}")
          Logger.info("       Version: #{info.version}")
          Logger.info("       Path: #{info.path}")
          Logger.info("       Capabilities: #{inspect(info.capabilities)}")
          Logger.info("       Status: #{info.status}")
          
          # Check if the installation actually exists
          if File.exists?(info.path) do
            Logger.info("       ✅ Installation directory exists")
            
            # Check for package.json
            package_json = Path.join(info.path, "package.json")
            if File.exists?(package_json) do
              case File.read(package_json) do
                {:ok, content} ->
                  case Jason.decode(content) do
                    {:ok, json} ->
                      if json["name"] == name do
                        Logger.info("       ✅ Valid package.json with correct name")
                      end
                    _ -> nil
                  end
                _ -> nil
              end
            end
            
            # Check for node_modules
            node_modules = Path.join(info.path, "node_modules")
            if File.exists?(node_modules) do
              Logger.info("       ✅ node_modules directory exists")
              
              # Check if the actual MCP server is installed
              server_dir = Path.join([node_modules | String.split(name, "/")])
              if File.exists?(server_dir) do
                Logger.info("       ✅ MCP server package installed at #{server_dir}")
              end
            end
          else
            Logger.error("       ❌ Installation directory missing!")
          end
        end)
        
      {:ok, _} ->
        Logger.info("  ⚠️  No MCP servers installed yet")
        Logger.info("     The system may need more time or a larger variety gap")
        
      {:error, reason} ->
        Logger.error("  ❌ Failed to list servers: #{inspect(reason)}")
    end
  end
end

# Run the gap injection
InjectVarietyGap.run()