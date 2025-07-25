#!/usr/bin/env elixir

# Test MCP functionality with proper compilation

IO.puts("🔧 Compiling VSM-MCP project first...")
System.cmd("mix", ["compile"], cd: ".", into: IO.stream(:stdio, :line))

IO.puts("\n🔍 Testing MCP Client with Filesystem Server")
IO.puts("=" <> String.duplicate("=", 79))

# Now run the test in the Mix environment
test_code = """
defmodule TestMCP do
  def run do
    IO.puts("\\n1️⃣ Starting MCP Client for filesystem server...")
    
    # Start the application to ensure dependencies are loaded
    {:ok, _} = Application.ensure_all_started(:vsm_mcp)
    
    # Create MCP client for filesystem server
    opts = [
      name: :fs_mcp_client,
      transport: :stdio,
      connection: %{
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
      }
    ]
    
    case VsmMcp.MCP.Client.start_link(opts) do
      {:ok, client} ->
        IO.puts("  ✅ Client started")
        
        # Connect to the server
        case VsmMcp.MCP.Client.connect(client) do
          :ok ->
            IO.puts("  ✅ Connected to filesystem MCP server!")
            
            # List available tools
            IO.puts("\\n2️⃣ Listing available tools...")
            case VsmMcp.MCP.Client.list_tools(client) do
              {:ok, tools} ->
                IO.puts("  ✅ Found \#{length(tools)} tools:")
                Enum.each(tools, fn tool ->
                  IO.puts("     📌 \#{tool["name"]}")
                end)
                
                # Test actual file operations
                test_file_operations(client)
                
              {:error, reason} ->
                IO.puts("  ❌ Failed to list tools: \#{inspect(reason)}")
            end
            
          {:error, reason} ->
            IO.puts("  ❌ Failed to connect: \#{inspect(reason)}")
        end
        
      {:error, reason} ->
        IO.puts("  ❌ Failed to start client: \#{inspect(reason)}")
    end
  end
  
  defp test_file_operations(client) do
    IO.puts("\\n3️⃣ Testing file operations...")
    
    # Test 1: List directory
    IO.puts("\\n  📁 Listing /tmp directory...")
    case VsmMcp.MCP.Client.call_tool(client, "list_directory", %{"path" => "/tmp"}) do
      {:ok, %{"content" => content}} ->
        files = content |> String.split("\\n") |> Enum.take(5)
        IO.puts("  ✅ Directory listing successful! First 5 entries:")
        Enum.each(files, &IO.puts("     - \#{&1}"))
        
      {:ok, result} ->
        IO.puts("  ✅ Got result: \#{inspect(result)}")
        
      {:error, reason} ->
        IO.puts("  ❌ Failed: \#{inspect(reason)}")
    end
    
    # Test 2: Read a file
    IO.puts("\\n  📄 Reading /etc/hostname...")
    case VsmMcp.MCP.Client.call_tool(client, "read_file", %{"path" => "/etc/hostname"}) do
      {:ok, %{"content" => content}} ->
        IO.puts("  ✅ File content: \#{String.trim(content)}")
        
      {:ok, result} ->
        IO.puts("  ✅ Got result: \#{inspect(result)}")
        
      {:error, reason} ->
        IO.puts("  ❌ Failed: \#{inspect(reason)}")
    end
    
    # Test 3: Write and read back
    test_file = "/tmp/vsm_mcp_test_\#{:os.system_time(:millisecond)}.txt"
    test_content = "VSM-MCP can use real MCP servers!"
    
    IO.puts("\\n  📝 Writing test file \#{test_file}...")
    case VsmMcp.MCP.Client.call_tool(client, "write_file", %{
      "path" => test_file, 
      "content" => test_content
    }) do
      {:ok, _} ->
        IO.puts("  ✅ File written successfully!")
        
        # Read it back
        IO.puts("  📖 Reading back the file...")
        case VsmMcp.MCP.Client.call_tool(client, "read_file", %{"path" => test_file}) do
          {:ok, %{"content" => read_content}} ->
            if String.trim(read_content) == test_content do
              IO.puts("  ✅ Content matches! MCP server is working correctly!")
            else
              IO.puts("  ⚠️  Content mismatch")
            end
            
          {:error, reason} ->
            IO.puts("  ❌ Failed to read back: \#{inspect(reason)}")
        end
        
      {:error, reason} ->
        IO.puts("  ❌ Failed to write: \#{inspect(reason)}")
    end
    
    # Clean up
    VsmMcp.MCP.Client.disconnect(client)
  end
end

TestMCP.run()
"""

# Save the test code
File.write!("test_mcp_runner.exs", test_code)

# Run it with mix
IO.puts("\n🚀 Running MCP test with Mix...")
System.cmd("mix", ["run", "test_mcp_runner.exs"], 
  cd: ".",
  into: IO.stream(:stdio, :line),
  env: [{"MIX_ENV", "dev"}]
)

# Clean up
File.rm("test_mcp_runner.exs")

IO.puts("\n\n📊 Test Summary")
IO.puts("=" <> String.duplicate("=", 79))
IO.puts("""
This test attempted to:
1. Connect to a real MCP server (filesystem server)
2. List available tools from the server
3. Perform actual file operations (list, read, write)

If the test shows:
- ✅ Connected to filesystem MCP server
- ✅ Tools listed (read_file, write_file, list_directory)
- ✅ File operations succeeded
Then VSM-MCP DOES use real MCP servers for capabilities.

If the test shows:
- ❌ Connection failures
- ❌ No real file operations
- ❌ Fallback responses
Then VSM-MCP does NOT actually use MCP servers.
""")