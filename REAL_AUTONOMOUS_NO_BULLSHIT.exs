#!/usr/bin/env elixir

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║         REAL AUTONOMOUS MCP - NO BULLSHIT                  ║
╚═══════════════════════════════════════════════════════════╝

This will ACTUALLY:
1. Search NPM for real MCP servers
2. Install them with npm
3. Start the processes
4. Establish JSON-RPC communication
"""

defmodule RealMCPAutonomous do
  require Logger
  
  @install_dir "/tmp/vsm_mcp_real_test"
  
  def run do
    # Create install directory
    File.mkdir_p!(@install_dir)
    
    # 1. REAL NPM SEARCH
    IO.puts("\n1️⃣ SEARCHING NPM FOR REAL MCP SERVERS...")
    
    search_results = search_npm_for_real("filesystem")
    
    if length(search_results) == 0 do
      IO.puts("❌ No MCP servers found on NPM")
      # Try a known package
      IO.puts("🔍 Trying known MCP package: @modelcontextprotocol/server-filesystem")
      install_known_package()
    else
      IO.puts("✅ Found #{length(search_results)} packages")
      
      # Install first result
      package = List.first(search_results)
      install_and_run(package)
    end
  end
  
  defp search_npm_for_real(keyword) do
    url = "https://registry.npmjs.org/-/v1/search?text=mcp-server-#{keyword}&size=5"
    
    case HTTPoison.get(url, [{"Accept", "application/json"}], recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"objects" => objects}} ->
            objects
            |> Enum.map(& &1["package"])
            |> Enum.filter(&String.contains?(&1["name"], "mcp"))
          _ -> []
        end
      error ->
        IO.puts("❌ NPM search error: #{inspect(error)}")
        []
    end
  end
  
  defp install_known_package do
    package = %{
      "name" => "@modelcontextprotocol/server-filesystem",
      "version" => "latest"
    }
    install_and_run(package)
  end
  
  defp install_and_run(package) do
    name = package["name"]
    
    IO.puts("\n2️⃣ INSTALLING #{name} FOR REAL...")
    
    # REAL NPM INSTALL
    install_cmd = "cd #{@install_dir} && npm install #{name} --no-save"
    IO.puts("   Running: #{install_cmd}")
    
    case System.cmd("bash", ["-c", install_cmd], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ SUCCESSFULLY INSTALLED!")
        IO.puts("   Output: #{String.slice(output, 0..200)}...")
        
        # Find the installed package
        find_and_start_server(name)
        
      {error, code} ->
        IO.puts("❌ NPM INSTALL FAILED (code #{code})")
        IO.puts("   Error: #{error}")
    end
  end
  
  defp find_and_start_server(name) do
    IO.puts("\n3️⃣ STARTING MCP SERVER PROCESS...")
    
    # Try to find the executable
    base_name = String.replace(name, ~r/^@[^\/]+\//, "")
    possible_paths = [
      Path.join([@install_dir, "node_modules", name, "dist", "index.js"]),
      Path.join([@install_dir, "node_modules", name, "index.js"]),
      Path.join([@install_dir, "node_modules", ".bin", base_name])
    ]
    
    executable = Enum.find(possible_paths, &File.exists?/1)
    
    if executable do
      IO.puts("   Found executable: #{executable}")
      
      # Start the server with stdio transport
      port = Port.open({:spawn_executable, "/usr/bin/node"}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: [executable, "stdio"],
        cd: @install_dir
      ])
      
      IO.puts("✅ MCP SERVER STARTED! Port: #{inspect(port)}")
      
      # Send initialization
      init_message = Jason.encode!(%{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{},
          "clientInfo" => %{
            "name" => "VSM-MCP",
            "version" => "1.0.0"
          }
        },
        "id" => 1
      })
      
      Port.command(port, init_message <> "\n")
      
      # Wait for response
      receive do
        {^port, {:data, data}} ->
          IO.puts("\n📨 RECEIVED RESPONSE FROM MCP SERVER:")
          IO.puts(data)
          
          # Try to decode
          case Jason.decode(data) do
            {:ok, response} ->
              IO.puts("\n✅ SUCCESSFULLY COMMUNICATED WITH MCP SERVER!")
              IO.puts("   Server responded with: #{inspect(response["result"])}")
            _ ->
              IO.puts("   Raw response: #{data}")
          end
      after
        5000 ->
          IO.puts("⏱️  No response after 5 seconds")
      end
      
      # Close port
      Port.close(port)
      
    else
      IO.puts("❌ Could not find executable")
      IO.puts("   Searched: #{inspect(possible_paths)}")
      
      # List what we have
      IO.puts("\n📁 Contents of node_modules:")
      {files, _} = System.cmd("ls", ["-la", Path.join(@install_dir, "node_modules")], stderr_to_stdout: true)
      IO.puts(files)
    end
  end
end

# Ensure HTTPoison is started
Application.ensure_all_started(:httpoison)

# RUN IT!
RealMCPAutonomous.run()

IO.puts """

╔═══════════════════════════════════════════════════════════╗
║                    CONCLUSION                              ║
║                                                            ║
║  If this worked, we ACTUALLY:                             ║
║  • Searched real NPM registry                             ║
║  • Installed a real MCP server                            ║
║  • Started a real process                                 ║
║  • Communicated via JSON-RPC                              ║
║                                                           ║
║  If it failed, at least we tried FOR REAL!               ║
╚═══════════════════════════════════════════════════════════╝
"""