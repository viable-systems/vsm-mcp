#!/usr/bin/env elixir

# Test to prove VSM-MCP actually uses real MCP servers for capabilities
# This test requests filesystem operations that ONLY the MCP server can provide

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.3"},
  {:uuid, "~> 1.1"}
])

defmodule RealMCPUsageTest do
  @moduledoc """
  Test that definitively proves whether VSM-MCP uses real MCP servers
  by requesting capabilities that cannot be fulfilled internally.
  """

  def run_test do
    IO.puts("\n🔍 VSM-MCP Real MCP Server Usage Test")
    IO.puts("=" <> String.duplicate("=", 79))
    
    # Test 1: Request that requires filesystem MCP server
    test_filesystem_capability()
    
    # Test 2: Request multiple file operations
    test_complex_filesystem_operations()
    
    # Test 3: Request with specific MCP server targeting
    test_targeted_mcp_request()
  end

  defp test_filesystem_capability do
    IO.puts("\n📁 Test 1: Filesystem Capability Request")
    IO.puts("Requesting: List all Python files in /usr/lib/python3")
    IO.puts("-" <> String.duplicate("-", 79))
    
    request = %{
      "context" => %{
        "request" => "List all Python files in the /usr/lib/python3 directory",
        "requires_capability" => "filesystem_access",
        "cannot_be_simulated" => true
      },
      "force_mcp_usage" => true,
      "validate_source" => true
    }
    
    case make_vsm_request(request) do
      {:ok, response} ->
        IO.puts("✅ Response received:")
        IO.inspect(response, pretty: true, limit: :infinity)
        
        # Check if response indicates MCP server usage
        validate_mcp_usage(response, "filesystem")
        
      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end

  defp test_complex_filesystem_operations do
    IO.puts("\n📂 Test 2: Complex Filesystem Operations")
    IO.puts("Requesting: Directory structure analysis")
    IO.puts("-" <> String.duplicate("-", 79))
    
    request = %{
      "context" => %{
        "request" => "Analyze the directory structure of /etc, count config files, and list subdirectories",
        "operations" => [
          "list_directories",
          "count_files_by_extension",
          "get_file_stats"
        ],
        "requires_mcp" => true
      },
      "trace_execution" => true
    }
    
    case make_vsm_request(request) do
      {:ok, response} ->
        IO.puts("✅ Response received:")
        IO.inspect(response, pretty: true, limit: :infinity)
        
        # Check execution trace
        if trace = response["execution_trace"] do
          IO.puts("\n🔍 Execution Trace:")
          Enum.each(trace, fn step ->
            IO.puts("  - #{step}")
          end)
        end
        
      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end

  defp test_targeted_mcp_request do
    IO.puts("\n🎯 Test 3: Targeted MCP Server Request")
    IO.puts("Requesting: Specific MCP server usage")
    IO.puts("-" <> String.duplicate("-", 79))
    
    request = %{
      "context" => %{
        "request" => "Use the filesystem MCP server to read the contents of /proc/version",
        "target_mcp_server" => "filesystem",
        "validate_response_source" => true
      },
      "include_mcp_metadata" => true
    }
    
    case make_vsm_request(request) do
      {:ok, response} ->
        IO.puts("✅ Response received:")
        IO.inspect(response, pretty: true, limit: :infinity)
        
        # Check MCP metadata
        if metadata = response["mcp_metadata"] do
          IO.puts("\n📊 MCP Metadata:")
          IO.puts("  Server: #{metadata["server_name"] || "Unknown"}")
          IO.puts("  Method: #{metadata["method_used"] || "Unknown"}")
          IO.puts("  Response Time: #{metadata["response_time_ms"] || "Unknown"}ms")
        end
        
      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end

  defp make_vsm_request(request) do
    # Try different endpoints to find the working one
    endpoints = [
      "http://localhost:4000/api/v1/variety/analyze",
      "http://localhost:4000/api/v1/consciousness/decide",
      "http://localhost:4000/api/v1/vsm/process"
    ]
    
    # First, check if the server is running
    case check_server_status() do
      :not_running ->
        IO.puts("⚠️  VSM-MCP server not running. Starting it...")
        start_vsm_server()
        Process.sleep(3000)
      :running ->
        IO.puts("✅ VSM-MCP server is running")
    end
    
    # Try each endpoint
    Enum.reduce_while(endpoints, {:error, "No working endpoint found"}, fn endpoint, _acc ->
      IO.puts("\n🔌 Trying endpoint: #{endpoint}")
      
      case Req.post(endpoint, json: request, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: body}} ->
          {:halt, {:ok, body}}
          
        {:ok, %{status: status, body: body}} ->
          IO.puts("  ⚠️  Status #{status}: #{inspect(body)}")
          {:cont, {:error, "Status #{status}"}}
          
        {:error, error} ->
          IO.puts("  ❌ Connection error: #{inspect(error)}")
          {:cont, {:error, error}}
      end
    end)
  end

  defp validate_mcp_usage(response, expected_server) do
    IO.puts("\n🔍 Validating MCP Usage:")
    
    # Check for indicators of actual MCP usage
    indicators = [
      {"mcp_server_used", response["mcp_server_used"]},
      {"capability_source", response["capability_source"]},
      {"external_call_made", response["external_call_made"]},
      {"response_source", response["response_source"]}
    ]
    
    Enum.each(indicators, fn {key, value} ->
      if value do
        IO.puts("  ✅ #{key}: #{inspect(value)}")
      else
        IO.puts("  ❌ #{key}: Not found")
      end
    end)
    
    # Check if the response contains filesystem data
    if response["result"] do
      case response["result"] do
        %{"files" => files} when is_list(files) ->
          IO.puts("\n📋 Files found: #{length(files)}")
          Enum.take(files, 5) |> Enum.each(&IO.puts("  - #{&1}"))
          
        %{"error" => error} ->
          IO.puts("\n⚠️  Error in result: #{error}")
          
        other ->
          IO.puts("\n📝 Result: #{inspect(other)}")
      end
    end
  end

  defp check_server_status do
    case Req.get("http://localhost:4000/health") do
      {:ok, %{status: 200}} -> :running
      _ -> :not_running
    end
  end

  defp start_vsm_server do
    IO.puts("🚀 Starting VSM-MCP server...")
    System.cmd("mix", ["phx.server"], 
      cd: "/home/batmanosama/viable-systems/vsm-mcp",
      into: IO.stream(:stdio, :line),
      env: [{"MIX_ENV", "dev"}]
    )
  end
end

# Run the test
RealMCPUsageTest.run_test()

IO.puts("\n\n📊 Test Summary:")
IO.puts("=" <> String.duplicate("=", 79))
IO.puts("""
This test attempted to:
1. Request filesystem operations that ONLY an MCP server can provide
2. Validate that the response came from an actual MCP server
3. Check for MCP-specific metadata and execution traces

If the responses show:
- ✅ Actual file listings from system directories
- ✅ MCP server metadata in responses
- ✅ Execution traces showing MCP calls
Then VSM-MCP DOES use real MCP servers.

If the responses show:
- ❌ Simulated or generic responses
- ❌ No MCP metadata
- ❌ Fallback behavior
Then VSM-MCP does NOT actually use MCP servers.
""")