#!/usr/bin/env elixir

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║          SIMPLE DIRECT MCP INSTALLATION TEST               ║
╚═══════════════════════════════════════════════════════════╝
"""

# Direct test - search and install a real MCP server
defmodule SimpleMCPTest do
  def search_npm_for_mcp(term) do
    url = "https://registry.npmjs.org/-/v1/search?text=#{URI.encode(term)}&size=10"
    
    IO.puts "🔍 Searching NPM for: #{term}"
    
    case HTTPoison.get(url, [], recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"objects" => objects, "total" => total}} ->
            IO.puts "✅ Found #{total} packages"
            
            # Filter for actual MCP servers
            mcp_servers = objects
            |> Enum.filter(fn obj ->
              name = obj["package"]["name"]
              desc = obj["package"]["description"] || ""
              
              String.contains?(name, "mcp") || 
              String.contains?(desc, "Model Context Protocol") ||
              String.contains?(desc, "MCP server")
            end)
            
            IO.puts "🎯 Found #{length(mcp_servers)} MCP servers:"
            
            Enum.each(mcp_servers, fn obj ->
              pkg = obj["package"]
              IO.puts "   - #{pkg["name"]} v#{pkg["version"]}"
              IO.puts "     #{String.slice(pkg["description"] || "", 0..60)}..."
            end)
            
            {:ok, mcp_servers}
            
          {:ok, _} ->
            {:error, "Invalid response format"}
          
          {:error, reason} ->
            {:error, "JSON decode failed: #{inspect(reason)}"}
        end
        
      {:ok, %{status_code: code}} ->
        {:error, "NPM returned status #{code}"}
        
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
  
  def install_mcp_server(package_name) do
    install_dir = "/tmp/vsm_mcp_test_#{:rand.uniform(10000)}"
    File.mkdir_p!(install_dir)
    
    IO.puts "\n📦 Installing #{package_name} to #{install_dir}..."
    
    case System.cmd("npm", ["install", package_name, "--prefix", install_dir], 
                   stderr_to_stdout: true, cd: install_dir) do
      {output, 0} ->
        IO.puts "✅ Installation successful!"
        
        # List installed files
        {files, _} = System.cmd("find", [install_dir, "-name", "*.js", "-type", "f"], 
                               stderr_to_stdout: true)
        js_files = String.split(files, "\n") |> Enum.filter(&(&1 != ""))
        
        IO.puts "📁 Installed #{length(js_files)} JavaScript files"
        
        # Check package.json
        pkg_json = Path.join([install_dir, "node_modules", package_name, "package.json"])
        if File.exists?(pkg_json) do
          {:ok, content} = File.read(pkg_json)
          {:ok, pkg_data} = Jason.decode(content)
          
          IO.puts "\n📋 Package info:"
          IO.puts "   Name: #{pkg_data["name"]}"
          IO.puts "   Version: #{pkg_data["version"]}"
          IO.puts "   Description: #{pkg_data["description"]}"
          
          if pkg_data["bin"] do
            IO.puts "   Executable: YES ✅"
          end
        end
        
        {:ok, install_dir}
        
      {error, code} ->
        IO.puts "❌ Installation failed (exit code #{code})"
        IO.puts "Error: #{String.slice(error, 0..500)}"
        {:error, code}
    end
  end
end

# Start dependencies
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:jason)

# Test 1: Search for MCP servers
IO.puts "\n🧪 TEST 1: Search for real MCP servers"
SimpleMCPTest.search_npm_for_mcp("@modelcontextprotocol")

IO.puts "\n" <> String.duplicate("-", 60) <> "\n"

# Test 2: Search for community MCP servers  
IO.puts "🧪 TEST 2: Search for community MCP servers"
SimpleMCPTest.search_npm_for_mcp("mcp-server")

IO.puts "\n" <> String.duplicate("-", 60) <> "\n"

# Test 3: Try to install a real MCP server
IO.puts "🧪 TEST 3: Install a real MCP server"

# Try to install the filesystem MCP server
case SimpleMCPTest.install_mcp_server("@modelcontextprotocol/server-filesystem") do
  {:ok, dir} ->
    IO.puts "\n✅ SUCCESS! MCP server installed at: #{dir}"
    IO.puts "\nYou can verify with:"
    IO.puts "  ls -la #{dir}/node_modules/"
  {:error, _} ->
    # Try a community server instead
    IO.puts "\nTrying community server instead..."
    SimpleMCPTest.install_mcp_server("mcp-server-sqlite")
end

IO.puts "\n✅ Test complete!"