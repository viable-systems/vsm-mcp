#!/usr/bin/env elixir
# Test script to verify real MCP server discovery and installation

Mix.install([
  {:vsm_mcp, path: "."},
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.4"}
])

require Logger

defmodule TestRealMCPDiscovery do
  def run do
    Logger.info("🚀 Testing Real MCP Server Discovery and Installation")
    
    # Start required processes
    {:ok, _} = Application.ensure_all_started(:httpoison)
    {:ok, _} = VsmMcp.Core.MCPDiscovery.start_link()
    
    # Test 1: Test capability mapping
    test_capability_mapping()
    
    # Test 2: Test discovery with generic terms
    test_generic_discovery()
    
    # Test 3: Test discovery with real package names
    test_real_package_discovery()
    
    # Test 4: Test actual installation
    test_installation()
    
    # Test 5: Simulate variety gap and autonomous acquisition
    test_autonomous_acquisition()
  end
  
  defp test_capability_mapping do
    Logger.info("\n📋 Test 1: Capability Mapping")
    
    test_cases = [
      {"enhanced_processing", "Maps to real MCP servers"},
      {"filesystem", "Maps to filesystem server"},
      {"database", "Maps to database servers"},
      {"parallel_processing", "Maps to container/k8s servers"}
    ]
    
    Enum.each(test_cases, fn {capability, desc} ->
      packages = VsmMcp.Core.CapabilityMapping.map_capability_to_packages(capability)
      Logger.info("  #{capability} -> #{inspect(packages)}")
      
      if Enum.empty?(packages) do
        Logger.error("  ❌ No packages mapped for #{capability}")
      else
        Logger.info("  ✅ #{desc}: #{length(packages)} packages")
      end
    end)
  end
  
  defp test_generic_discovery do
    Logger.info("\n🔍 Test 2: Discovery with Generic Terms")
    
    # Test discovering servers using generic capability names
    case VsmMcp.Core.MCPDiscovery.discover_servers(["filesystem", "memory", "database"]) do
      {:ok, servers} ->
        Logger.info("  Found #{length(servers)} servers")
        
        Enum.each(servers, fn server ->
          Logger.info("  📦 #{server.name} v#{server.version}")
          Logger.info("     Score: #{Float.round(server.relevance_score, 2)}")
          Logger.info("     Capabilities: #{inspect(server.capabilities)}")
        end)
        
        if length(servers) > 0 do
          Logger.info("  ✅ Successfully discovered real MCP servers")
        else
          Logger.error("  ❌ No servers found")
        end
        
      {:error, reason} ->
        Logger.error("  ❌ Discovery failed: #{inspect(reason)}")
    end
  end
  
  defp test_real_package_discovery do
    Logger.info("\n🔍 Test 3: Discovery with Real Package Names")
    
    # Test with actual MCP package names
    real_packages = [
      "@modelcontextprotocol/server-filesystem",
      "@modelcontextprotocol/server-memory",
      "@modelcontextprotocol/server-sqlite"
    ]
    
    case VsmMcp.Core.MCPDiscovery.search_mcp_servers(real_packages) do
      {:ok, servers} ->
        Logger.info("  Found #{length(servers)} servers")
        
        Enum.each(servers, fn server ->
          Logger.info("  📦 #{server.name} v#{server.version}")
          
          # Verify these are real packages
          if server.name in real_packages do
            Logger.info("     ✅ Verified real MCP package")
          end
        end)
        
      {:error, reason} ->
        Logger.error("  ❌ Search failed: #{inspect(reason)}")
    end
  end
  
  defp test_installation do
    Logger.info("\n📥 Test 4: Installing Real MCP Server")
    
    # Try to install a small, real MCP server
    test_server = %{
      name: "@modelcontextprotocol/server-memory",
      version: "latest",
      source: :npm,
      install_command: "npm install @modelcontextprotocol/server-memory",
      capabilities: [:memory, :caching]
    }
    
    Logger.info("  Attempting to install: #{test_server.name}")
    
    case VsmMcp.Core.MCPDiscovery.install_mcp_server(test_server) do
      {:ok, installation} ->
        Logger.info("  ✅ Successfully installed!")
        Logger.info("     Path: #{installation.path}")
        Logger.info("     Status: #{installation.status}")
        
        # Check if files exist
        if File.exists?(installation.path) do
          Logger.info("     ✅ Installation directory exists")
          
          package_json = Path.join(installation.path, "package.json")
          if File.exists?(package_json) do
            Logger.info("     ✅ package.json exists")
          end
          
          node_modules = Path.join(installation.path, "node_modules")
          if File.exists?(node_modules) do
            Logger.info("     ✅ node_modules exists")
          end
        end
        
      {:error, reason} ->
        Logger.error("  ❌ Installation failed: #{inspect(reason)}")
    end
  end
  
  defp test_autonomous_acquisition do
    Logger.info("\n🤖 Test 5: Autonomous Capability Acquisition")
    
    # Simulate a variety gap scenario
    required_capabilities = [
      %{type: "filesystem", search_terms: ["file", "fs"]},
      %{type: "memory", search_terms: ["cache", "storage"]},
      %{type: "api", search_terms: ["fetch", "http"]}
    ]
    
    Logger.info("  Simulating variety gap with required capabilities:")
    Enum.each(required_capabilities, fn cap ->
      Logger.info("    - #{cap.type}")
    end)
    
    case VsmMcp.Core.MCPDiscovery.discover_and_acquire(required_capabilities) do
      {:ok, result} ->
        Logger.info("\n  📊 Acquisition Results:")
        Logger.info("     Searched: #{result.searched} servers")
        Logger.info("     Selected: #{result.selected} servers")
        Logger.info("     Installed: #{result.installed} servers")
        Logger.info("     Success: #{result.success}")
        
        Logger.info("\n  🎯 Capability Mapping:")
        Enum.each(result.capabilities, fn {capability, servers} ->
          Logger.info("     #{capability} -> #{inspect(servers)}")
        end)
        
        if result.success do
          Logger.info("\n  ✅ Autonomous acquisition successful!")
        else
          Logger.error("\n  ❌ Autonomous acquisition failed")
        end
        
      {:error, reason} ->
        Logger.error("  ❌ Acquisition failed: #{inspect(reason)}")
    end
  end
end

# Run the tests
TestRealMCPDiscovery.run()

Logger.info("\n✨ Test completed!")