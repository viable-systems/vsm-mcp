#!/usr/bin/env elixir

# MCP Integration Validation Script
# Tests the core MCP integration functionality without complex setup

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule MCPIntegrationValidator do
  @moduledoc """
  Validates MCP integration system functionality.
  """
  
  require Logger
  
  def run_validation do
    Logger.info("Starting MCP Integration Validation...")
    
    results = [
      test_mcp_api_structure(),
      test_integration_module_structure(),
      test_server_manager_structure(),
      test_installer_structure(),
      test_dynamic_spawner_structure(),
      test_basic_mcp_functionality()
    ]
    
    passed = Enum.count(results, &(&1 == :ok))
    total = length(results)
    
    Logger.info("Validation Results: #{passed}/#{total} tests passed")
    
    if passed == total do
      Logger.info("✅ All MCP integration components validated successfully!")
      System.halt(0)
    else
      Logger.error("❌ Some validation tests failed")
      System.halt(1)
    end
  end
  
  defp test_mcp_api_structure do
    Logger.info("Testing MCP API structure...")
    
    try do
      # Test if MCP module exists and has required functions
      functions = VsmMcp.MCP.__info__(:functions)
      
      required_functions = [
        {:start_client, 1},
        {:start_server, 1},
        {:connect, 1},
        {:list_tools, 1},
        {:call_tool, 3},
        {:list_resources, 1},
        {:read_resource, 2}
      ]
      
      missing = Enum.reject(required_functions, fn func ->
        func in functions
      end)
      
      if Enum.empty?(missing) do
        Logger.info("✅ MCP API structure valid")
        :ok
      else
        Logger.error("❌ Missing MCP API functions: #{inspect(missing)}")
        :error
      end
    rescue
      e ->
        Logger.error("❌ MCP module not available: #{inspect(e)}")
        :error
    end
  end
  
  defp test_integration_module_structure do
    Logger.info("Testing Integration module structure...")
    
    try do
      functions = VsmMcp.Integration.__info__(:functions)
      
      required_functions = [
        {:start_link, 1},
        {:integrate_capability, 2},
        {:list_capabilities, 0},
        {:remove_capability, 1}
      ]
      
      missing = Enum.reject(required_functions, fn func ->
        func in functions
      end)
      
      if Enum.empty?(missing) do
        Logger.info("✅ Integration module structure valid")
        :ok
      else
        Logger.error("❌ Missing Integration functions: #{inspect(missing)}")
        :error
      end
    rescue
      e ->
        Logger.error("❌ Integration module not available: #{inspect(e)}")
        :error
    end
  end
  
  defp test_server_manager_structure do
    Logger.info("Testing ServerManager structure...")
    
    try do
      functions = VsmMcp.MCP.ServerManager.__info__(:functions)
      
      required_functions = [
        {:start_link, 1},
        {:start_server, 2},
        {:stop_server, 3},
        {:get_status, 1}
      ]
      
      missing = Enum.reject(required_functions, fn func ->
        func in functions
      end)
      
      if Enum.empty?(missing) do
        Logger.info("✅ ServerManager structure valid")
        :ok
      else
        Logger.error("❌ Missing ServerManager functions: #{inspect(missing)}")
        :error
      end
    rescue
      e ->
        Logger.error("❌ ServerManager module not available: #{inspect(e)}")
        :error
    end
  end
  
  defp test_installer_structure do
    Logger.info("Testing Installer structure...")
    
    try do
      functions = VsmMcp.Integration.Installer.__info__(:functions)
      
      required_functions = [
        {:install_server, 1},
        {:uninstall_server, 1},
        {:verify_installation, 1}
      ]
      
      missing = Enum.reject(required_functions, fn func ->
        func in functions
      end)
      
      if Enum.empty?(missing) do
        Logger.info("✅ Installer structure valid")
        :ok
      else
        Logger.error("❌ Missing Installer functions: #{inspect(missing)}")
        :error
      end
    rescue
      e ->
        Logger.error("❌ Installer module not available: #{inspect(e)}")
        :error
    end
  end
  
  defp test_dynamic_spawner_structure do
    Logger.info("Testing DynamicSpawner structure...")
    
    try do
      functions = VsmMcp.Integration.DynamicSpawner.__info__(:functions)
      
      required_functions = [
        {:start_link, 1},
        {:spawn_capability, 2},
        {:terminate_capability, 1},
        {:list_capabilities, 0}
      ]
      
      missing = Enum.reject(required_functions, fn func ->
        func in functions
      end)
      
      if Enum.empty?(missing) do
        Logger.info("✅ DynamicSpawner structure valid")
        :ok
      else
        Logger.error("❌ Missing DynamicSpawner functions: #{inspect(missing)}")
        :error
      end
    rescue
      e ->
        Logger.error("❌ DynamicSpawner module not available: #{inspect(e)}")
        :error
    end
  end
  
  defp test_basic_mcp_functionality do
    Logger.info("Testing basic MCP functionality...")
    
    try do
      # Test MCP server start
      server_result = VsmMcp.MCP.start_server([
        name: :validation_server,
        transport: :stdio,
        auto_start: false
      ])
      
      case server_result do
        {:ok, server_pid} ->
          Logger.info("✅ MCP server can be started")
          
          # Test client start
          client_result = VsmMcp.MCP.start_client([
            name: :validation_client,
            transport: :stdio,
            auto_connect: false
          ])
          
          case client_result do
            {:ok, client_pid} ->
              Logger.info("✅ MCP client can be started")
              
              # Cleanup
              if Process.alive?(server_pid), do: GenServer.stop(server_pid)
              if Process.alive?(client_pid), do: GenServer.stop(client_pid)
              
              :ok
              
            {:error, reason} ->
              Logger.error("❌ MCP client start failed: #{inspect(reason)}")
              if Process.alive?(server_pid), do: GenServer.stop(server_pid)
              :error
          end
          
        {:error, reason} ->
          Logger.error("❌ MCP server start failed: #{inspect(reason)}")
          :error
      end
    rescue
      e ->
        Logger.error("❌ MCP functionality test failed: #{inspect(e)}")
        :error
    end
  end
end

# Test if we're in the right directory and can access modules
try do
  Code.ensure_loaded(VsmMcp.MCP)
  Code.ensure_loaded(VsmMcp.Integration)
  
  MCPIntegrationValidator.run_validation()
rescue
  UndefinedFunctionError ->
    IO.puts("❌ VSM-MCP modules not available. Run from project root with: elixir -S mix run #{__ENV__.file}")
    System.halt(1)
    
  e ->
    IO.puts("❌ Error loading modules: #{inspect(e)}")
    System.halt(1)
end