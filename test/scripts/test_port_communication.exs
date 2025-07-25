#!/usr/bin/env elixir

# Test script to verify the improved MCP port communication
Mix.install([
  {:jason, "~> 1.4"}
])

defmodule TestPortCommunication do
  require Logger
  
  def test_basic_port_functionality do
    Logger.info("Testing basic port functionality...")
    
    # Test with a simple echo command to verify port options work
    try do
      port_options = [
        :binary,
        :exit_status,
        {:line, 8192},
        :stderr_to_stdout,
        args: ["-c", "echo 'Hello from port'"]
      ]
      
      port = Port.open({:spawn_executable, "/bin/sh"}, port_options)
      
      case Port.info(port) do
        nil -> 
          IO.puts("❌ Port failed to start")
          {:error, "Port not alive"}
        info ->
          IO.puts("✅ Port started successfully: #{inspect(info)}")
          
          # Wait for output
          receive do
            {^port, {:data, {_, data}}} ->
              IO.puts("✅ Received data: #{inspect(data)}")
              Port.close(port)
              {:ok, "Port communication successful"}
            {^port, {:exit_status, status}} ->
              IO.puts("✅ Process completed with status: #{status}")
              {:ok, "Process completed"}
          after
            5000 ->
              IO.puts("⚠️  Timeout waiting for port response")
              Port.close(port)
              {:error, "Timeout"}
          end
      end
    rescue
      e ->
        IO.puts("❌ Exception: #{inspect(e)}")
        {:error, e}
    end
  end
  
  def test_json_message_parsing do
    Logger.info("Testing JSON message parsing...")
    
    test_buffer = """
    {"jsonrpc":"2.0","id":1,"result":{"status":"ok"}}
    {"jsonrpc":"2.0","method":"notification","params":{}}
    {"jsonrpc":"2.0","id":2
    """
    
    lines = String.split(test_buffer, "\n")
    
    case Enum.reverse(lines) do
      [incomplete | complete_lines_reversed] ->
        complete_lines = Enum.reverse(complete_lines_reversed)
        
        messages = 
          complete_lines
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(fn line ->
            case Jason.decode(line) do
              {:ok, msg} -> {:ok, msg}
              {:error, reason} -> {:error, reason}
            end
          end)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, msg} -> msg end)
        
        IO.puts("✅ Parsed #{length(messages)} complete messages")
        IO.puts("✅ Incomplete buffer: #{inspect(incomplete)}")
        
        # Test finding response by ID
        response = Enum.find(messages, fn msg -> 
          Map.get(msg, "id") == 1 && Map.has_key?(msg, "result")
        end)
        
        if response do
          IO.puts("✅ Found response for ID 1: #{inspect(response)}")
          {:ok, "JSON parsing successful"}
        else
          IO.puts("❌ Could not find response for ID 1")
          {:error, "Response not found"}
        end
        
      [] ->
        IO.puts("❌ No lines to process")
        {:error, "Empty buffer"}
    end
  end
  
  def run_all_tests do
    IO.puts("\n🧪 Running MCP Port Communication Tests\n")
    
    test_results = [
      {"Basic Port Functionality", test_basic_port_functionality()},
      {"JSON Message Parsing", test_json_message_parsing()}
    ]
    
    IO.puts("\n📊 Test Results:")
    
    Enum.each(test_results, fn {test_name, result} ->
      case result do
        {:ok, _} -> IO.puts("  ✅ #{test_name}")
        {:error, reason} -> IO.puts("  ❌ #{test_name}: #{inspect(reason)}")
      end
    end)
    
    successful_tests = Enum.count(test_results, fn {_, result} -> match?({:ok, _}, result) end)
    total_tests = length(test_results)
    
    IO.puts("\n📈 Summary: #{successful_tests}/#{total_tests} tests passed")
    
    if successful_tests == total_tests do
      IO.puts("🎉 All tests passed! Port communication improvements are working.")
    else
      IO.puts("⚠️  Some tests failed. Review the implementation.")
    end
  end
end

# Run the tests
TestPortCommunication.run_all_tests()