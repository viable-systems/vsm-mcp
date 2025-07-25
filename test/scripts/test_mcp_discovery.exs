#!/usr/bin/env elixir

Mix.install([
  {:vsm_mcp, path: "."},
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

# Load environment
if File.exists?(".env") do
  File.read!(".env")
  |> String.split("\n")
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] when key != "" ->
        unless String.starts_with?(key, "#") do
          System.put_env(key, String.trim(value))
        end
      _ -> :ok
    end
  end)
end

# Start the application
{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:vsm_mcp)

Process.sleep(1000)

IO.puts "🔍 Testing MCP Server Discovery and Installation"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test discovery
case VsmMcp.RealImplementation.discover_real_mcp_servers() do
  {:ok, servers} ->
    IO.puts "\n✅ Found #{length(servers)} MCP servers:"
    servers
    |> Enum.take(5)  # Show first 5
    |> Enum.each(fn server ->
      IO.puts "  • #{server.name}: #{server.description || "No description"}"
    end)
    
    if length(servers) > 0 do
      server = hd(servers)
      IO.puts "\n🔧 Testing installation of: #{server.name}"
      
      # Test the capability acquisition with MCP integration
      acquisition_op = %{
        type: :capability_acquisition,
        target: "powerpoint_creation",
        method: :mcp_integration
      }
      
      case VsmMcp.Systems.System1.execute_operation(acquisition_op) do
        {:ok, result} ->
          IO.puts "\n✅ Capability acquisition result:"
          IO.puts "  • Method: #{result.method}"
          IO.puts "  • Details: #{result.details}"
          if Map.has_key?(result, :execution_result) do
            IO.puts "  • Execution: #{result.execution_result}"
          end
          
        {:error, reason} ->
          IO.puts "\n❌ Capability acquisition failed: #{reason}"
      end
    end
    
  {:error, reason} ->
    IO.puts "❌ Discovery failed: #{reason}"
end