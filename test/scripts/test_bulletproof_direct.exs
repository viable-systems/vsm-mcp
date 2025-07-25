#!/usr/bin/env elixir

user_prompt = "I need to create a excel spreadsheet on the 2024 draft nba"

IO.puts """
🚀 TESTING BULLETPROOF MCP IMPLEMENTATION
=========================================

Test Request: "#{user_prompt}"

🧠 Starting VSM-MCP system...
"""

# Test the execution
IO.puts "\n🎯 Executing autonomous capability acquisition..."

operation = %{
  type: :capability_acquisition,
  target: :spreadsheet_generation,
  method: :mcp_integration,
  context: %{
    user_prompt: user_prompt,
    domain: "data_processing",
    requirements: "Create Excel spreadsheet with 2024 NBA draft data",
    expected_output: "excel_file"
  }
}

execution_start = System.monotonic_time(:millisecond)

result = try do
  case VsmMcp.Systems.System1.execute_operation(operation) do
    {:ok, response} ->
      execution_time = System.monotonic_time(:millisecond) - execution_start
      
      IO.puts """
      
      ✅ EXECUTION SUCCESSFUL!
      =====================
      
      Execution time: #{execution_time}ms
      Status: #{inspect(response.status)}
      Method: #{inspect(response.method)}
      Capability: #{inspect(response.capability)}
      
      Server Management:
      - Port errors: #{if response[:port_error], do: "YES ❌", else: "NO ✅"}
      - JSON-RPC working: #{if response[:json_rpc_error], do: "NO ❌", else: "YES ✅"}
      - Server discovered: #{if response[:server], do: response.server, else: "None"}
      - Health check passed: #{if response[:health_check] == :healthy, do: "YES ✅", else: "NO ❌"}
      
      Details:
      #{inspect(response.details, pretty: true, limit: :infinity)}
      """
      
      {:ok, response}
      
    {:error, error} ->
      execution_time = System.monotonic_time(:millisecond) - execution_start
      
      IO.puts """
      
      ❌ EXECUTION FAILED
      ==================
      
      Time: #{execution_time}ms
      Error: #{inspect(error)}
      
      Common Issues:
      - Port not alive: #{String.contains?(to_string(error), "Port is not alive")}
      - JSON-RPC error: #{String.contains?(to_string(error), "json")}
      - Server not found: #{String.contains?(to_string(error), "not found")}
      """
      
      {:error, error}
  end
rescue
  e ->
    execution_time = System.monotonic_time(:millisecond) - execution_start
    
    IO.puts """
    
    ⚠️ SYSTEM EXCEPTION
    ==================
    
    Time: #{execution_time}ms
    Exception: #{inspect(e)}
    Stacktrace:
    #{Exception.format_stacktrace(__STACKTRACE__)}
    """
    
    {:exception, e}
end

# Check for artifacts
IO.puts "\n📁 CHECKING FOR ARTIFACTS..."

artifact_dirs = ["vsm_artifacts", "artifacts", "generated", "output", "."]
excel_files = Enum.flat_map(artifact_dirs, fn dir ->
  case File.ls(dir) do
    {:ok, files} -> 
      files
      |> Enum.filter(&String.ends_with?(&1, [".xlsx", ".xls", ".csv"]))
      |> Enum.map(&Path.join(dir, &1))
    {:error, _} -> []
  end
end)

if excel_files != [] do
  IO.puts "\n✅ EXCEL FILES CREATED:"
  Enum.each(excel_files, fn file ->
    case File.stat(file) do
      {:ok, stat} -> IO.puts "   📊 #{file} (#{stat.size} bytes)"
      _ -> IO.puts "   📊 #{file}"
    end
  end)
else
  IO.puts "\n⚠️ No Excel files found"
end

# Check MCP server processes
IO.puts "\n🔍 MCP SERVER PROCESS STATUS:"

servers = try do
  GenServer.call(VsmMcp.MCP.ServerManager, :list_servers, 5000)
rescue
  _ -> []
end

if servers == [] do
  IO.puts "   ⚠️ No MCP servers registered"
else
  Enum.each(servers, fn {id, info} ->
    IO.puts """
       Server: #{id}
       Status: #{info[:status] || "unknown"}
       Type: #{info[:type] || "unknown"}
       Health: #{info[:health] || "unknown"}
    """
  end)
end

# Final verdict
IO.puts """

🏁 BULLETPROOF MCP TEST COMPLETE
================================

Test Result: #{case result do
  {:ok, _} -> "✅ PASSED - System working correctly"
  {:error, reason} -> "❌ FAILED - #{inspect(reason)}"
  {:exception, _} -> "⚠️ EXCEPTION - System needs debugging"
end}

Key Metrics:
- No port errors: #{case result do
  {:ok, resp} -> if resp[:port_error], do: "❌", else: "✅"
  _ -> "❌"
end}
- JSON-RPC working: #{case result do
  {:ok, resp} -> if resp[:json_rpc_error], do: "❌", else: "✅"
  _ -> "❌"
end}
- Artifacts created: #{if excel_files != [], do: "✅", else: "❌"}
- Server management: #{if servers != [], do: "✅", else: "❌"}
"""