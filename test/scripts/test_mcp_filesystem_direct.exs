#!/usr/bin/env elixir

# Direct test of MCP Client connecting to filesystem MCP server

defmodule DirectMCPTest do
  @moduledoc """
  Test that directly uses VsmMcp.MCP.Client to connect to the filesystem MCP server
  """
  
  def run_test do
    IO.puts("\n🔍 Direct MCP Filesystem Server Test")
    IO.puts("=" <> String.duplicate("=", 79))
    
    # Check if the MCP modules exist
    IO.puts("\n1️⃣ Checking MCP modules...")
    check_modules()
    
    # Try to start and connect to filesystem MCP server
    IO.puts("\n2️⃣ Testing direct MCP client connection...")
    test_direct_mcp_connection()
    
    # Try using the client if it connects
    IO.puts("\n3️⃣ Testing MCP operations...")
    test_mcp_operations()
  end
  
  defp check_modules do
    modules = [
      VsmMcp.MCP.Client,
      VsmMcp.MCP.Server,
      VsmMcp.MCP.Protocol.Handler,
      VsmMcp.MCP.Transports.Stdio
    ]
    
    Enum.each(modules, fn module ->
      if Code.ensure_loaded?(module) do
        IO.puts("  ✅ #{inspect(module)} is available")
      else
        IO.puts("  ❌ #{inspect(module)} is NOT available")
      end
    end)
  end
  
  defp test_direct_mcp_connection do
    # Start the MCP client
    case VsmMcp.MCP.Client.start_link(
      name: :test_mcp_client,
      transport: :stdio,
      connection: %{
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
      }
    ) do
      {:ok, client} ->
        IO.puts("  ✅ MCP Client started: #{inspect(client)}")
        
        # Try to connect
        case VsmMcp.MCP.Client.connect(client) do
          :ok ->
            IO.puts("  ✅ Connected to MCP server!")
            
            # List tools
            case VsmMcp.MCP.Client.list_tools(client) do
              {:ok, tools} ->
                IO.puts("  ✅ Tools available: #{length(tools)}")
                Enum.each(tools, fn tool ->
                  IO.puts("     - #{tool["name"]}: #{tool["description"]}")
                end)
                
              {:error, reason} ->
                IO.puts("  ❌ Failed to list tools: #{inspect(reason)}")
            end
            
            # List resources
            case VsmMcp.MCP.Client.list_resources(client) do
              {:ok, resources} ->
                IO.puts("  ✅ Resources available: #{length(resources)}")
                
              {:error, reason} ->
                IO.puts("  ❌ Failed to list resources: #{inspect(reason)}")
            end
            
            {:ok, client}
            
          {:error, reason} ->
            IO.puts("  ❌ Failed to connect: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        IO.puts("  ❌ Failed to start MCP Client: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp test_mcp_operations do
    # Try to use the filesystem MCP server directly
    IO.puts("\n  Testing filesystem operations...")
    
    # Create a test client connected to filesystem server
    case start_filesystem_client() do
      {:ok, client} ->
        # Test 1: List files in /tmp
        IO.puts("\n  📁 Test: List files in /tmp")
        case VsmMcp.MCP.Client.call_tool(client, "list_directory", %{"path" => "/tmp"}) do
          {:ok, result} ->
            IO.puts("  ✅ Directory listing successful!")
            IO.inspect(result, pretty: true, limit: 5)
            
          {:error, reason} ->
            IO.puts("  ❌ Failed: #{inspect(reason)}")
        end
        
        # Test 2: Read a system file
        IO.puts("\n  📄 Test: Read /proc/version")
        case VsmMcp.MCP.Client.call_tool(client, "read_file", %{"path" => "/proc/version"}) do
          {:ok, result} ->
            IO.puts("  ✅ File read successful!")
            IO.inspect(result, pretty: true)
            
          {:error, reason} ->
            IO.puts("  ❌ Failed: #{inspect(reason)}")
        end
        
        # Clean up
        VsmMcp.MCP.Client.disconnect(client)
        
      {:error, reason} ->
        IO.puts("  ❌ Could not start filesystem client: #{inspect(reason)}")
    end
  end
  
  defp start_filesystem_client do
    # Start a client specifically for the filesystem server
    opts = [
      name: :filesystem_mcp_client,
      transport: :stdio,
      connection: %{
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/"]
      },
      auto_connect: true
    ]
    
    case VsmMcp.MCP.Client.start_link(opts) do
      {:ok, client} ->
        Process.sleep(1000)  # Give it time to connect
        {:ok, client}
        
      error ->
        error
    end
  end
end

# First ensure we can load the VSM-MCP modules
Code.prepend_path("_build/dev/lib/vsm_mcp/ebin")

# Run the test
DirectMCPTest.run_test()

IO.puts("\n\n📊 Test Conclusions:")
IO.puts("=" <> String.duplicate("=", 79))
IO.puts("""
If this test shows:
- ✅ MCP Client connects to filesystem server
- ✅ Tools are listed (like read_file, list_directory)
- ✅ Actual file operations work
Then VSM-MCP CAN use real MCP servers.

If this test shows:
- ❌ Connection failures
- ❌ No tools available
- ❌ Operations fail
Then VSM-MCP CANNOT actually use MCP servers.
""")