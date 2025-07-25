#!/usr/bin/env elixir

# Test directly spawning the filesystem MCP server

IO.puts("🔍 Direct MCP Server Process Test")
IO.puts("=" <> String.duplicate("=", 79))

# First, let's verify the filesystem server is installed
IO.puts("\n1️⃣ Checking if filesystem MCP server is available...")
case System.cmd("npx", ["-y", "@modelcontextprotocol/server-filesystem", "--help"], stderr_to_stdout: true) do
  {output, 0} ->
    IO.puts("  ✅ Filesystem server is available!")
    IO.puts("  Output: #{String.slice(output, 0, 100)}...")
    
  {error, code} ->
    IO.puts("  ❌ Failed to run filesystem server (exit code: #{code})")
    IO.puts("  Error: #{error}")
end

# Now let's try to spawn it as a port and communicate
IO.puts("\n2️⃣ Spawning filesystem MCP server as a port...")

port = Port.open({:spawn_executable, System.find_executable("npx")}, [
  :binary,
  :use_stdio,
  :exit_status,
  {:args, ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]},
  {:line, 1024}
])

IO.puts("  ✅ Port opened: #{inspect(port)}")

# Send an initialization request
init_request = Jason.encode!(%{
  "jsonrpc" => "2.0",
  "method" => "initialize",
  "id" => 1,
  "params" => %{
    "protocolVersion" => "2024-11-05",
    "capabilities" => %{
      "tools" => %{},
      "resources" => %{}
    },
    "clientInfo" => %{
      "name" => "test-client",
      "version" => "1.0.0"
    }
  }
})

IO.puts("\n3️⃣ Sending initialization request...")
Port.command(port, init_request <> "\n")

# Wait for response
IO.puts("  ⏳ Waiting for response...")
receive do
  {^port, {:data, {:eol, data}}} ->
    IO.puts("  ✅ Received response: #{data}")
    
    case Jason.decode(data) do
      {:ok, response} ->
        IO.puts("\n  📊 Decoded response:")
        IO.inspect(response, pretty: true)
        
        if response["result"] do
          IO.puts("\n  ✅ Server initialized successfully!")
          
          # Now try to list tools
          list_tools_request = Jason.encode!(%{
            "jsonrpc" => "2.0",
            "method" => "tools/list",
            "id" => 2,
            "params" => %{}
          })
          
          IO.puts("\n4️⃣ Listing available tools...")
          Port.command(port, list_tools_request <> "\n")
          
          receive do
            {^port, {:data, {:eol, tools_data}}} ->
              IO.puts("  ✅ Tools response: #{tools_data}")
              
              case Jason.decode(tools_data) do
                {:ok, tools_response} ->
                  if tools = tools_response["result"]["tools"] do
                    IO.puts("\n  📌 Available tools:")
                    Enum.each(tools, fn tool ->
                      IO.puts("     - #{tool["name"]}: #{tool["description"]}")
                    end)
                  end
                  
                {:error, _} ->
                  IO.puts("  ❌ Failed to decode tools response")
              end
              
            {^port, {:exit_status, status}} ->
              IO.puts("  ⚠️  Server exited with status: #{status}")
          after
            5_000 ->
              IO.puts("  ⏱️  Timeout waiting for tools response")
          end
        end
        
      {:error, reason} ->
        IO.puts("  ❌ Failed to decode response: #{inspect(reason)}")
    end
    
  {^port, {:exit_status, status}} ->
    IO.puts("  ⚠️  Server exited with status: #{status}")
    
  other ->
    IO.puts("  ❓ Unexpected message: #{inspect(other)}")
after
  5_000 ->
    IO.puts("  ⏱️  Timeout waiting for initialization response")
end

# Clean up
Port.close(port)

IO.puts("\n\n📊 Test Conclusions:")
IO.puts("=" <> String.duplicate("=", 79))
IO.puts("""
This test directly spawns the filesystem MCP server and communicates via stdio.

If this test shows:
- ✅ Server responds to initialization
- ✅ Tools are listed
- ✅ Real filesystem operations available
Then MCP servers CAN be used by Elixir code.

The issue may be in VSM-MCP's implementation of the client/transport.
""")