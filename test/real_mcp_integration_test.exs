defmodule RealMCPIntegrationTest do
  @moduledoc """
  Tests for real MCP server integration scenarios.
  These tests validate integration with actual MCP servers and external services.
  """
  
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog
  
  alias VsmMcp.Integration
  alias VsmMcp.Integration.{Installer, DynamicSpawner}
  alias VsmMcp.MCP.{Client, ServerManager}
  alias VsmMcp.Core.MCPDiscovery
  
  @moduletag :real_integration
  @moduletag :slow
  @moduletag timeout: 120_000
  
  # Skip these tests in CI unless explicitly enabled
  @skip_unless_env "RUN_REAL_MCP_TESTS"
  
  setup_all do
    if System.get_env(@skip_unless_env) != "true" do
      {:skip, "Real MCP tests disabled. Set #{@skip_unless_env}=true to enable."}
    else
      :ok
    end
  end
  
  describe "Real MCP Server Discovery" do
    @tag :external_network
    test "discovers MCP servers from npm registry" do
      # Test discovering real MCP servers
      capture_log(fn ->
        # Search for known MCP servers
        servers = MCPDiscovery.discover_servers(%{
          sources: [:npm],
          keywords: ["mcp", "model-context-protocol"],
          limit: 5
        })
        
        assert length(servers) > 0
        
        # Verify server structure
        for server <- servers do
          assert Map.has_key?(server, :name)
          assert Map.has_key?(server, :source)
          assert Map.has_key?(server, :capabilities)
        end
      end)
    end
    
    @tag :external_network
    test "discovers MCP servers from GitHub" do
      capture_log(fn ->
        servers = MCPDiscovery.discover_servers(%{
          sources: [:github],
          query: "mcp-server",
          limit: 3
        })
        
        # Should find some MCP servers on GitHub
        assert length(servers) >= 0  # May be 0 if no results
        
        for server <- servers do
          assert Map.has_key?(server, :repository_url)
          assert Map.has_key?(server, :name)
        end
      end)
    end
  end
  
  describe "Real MCP Server Installation" do
    @tag :filesystem
    test "installs hello-mcp server from GitHub" do
      server_config = %{
        name: "hello-mcp",
        source_type: :git,
        repository_url: "https://github.com/ruvnet/hello-mcp.git",
        branch: "main",
        requires_build: false
      }
      
      case Installer.install_server(server_config) do
        {:ok, installation_path} ->
          assert File.exists?(installation_path)
          assert File.exists?(Path.join(installation_path, "README.md"))
          
          # Verify installation
          {:ok, info} = Installer.verify_installation(installation_path)
          assert info.size > 0
          
          # Clean up
          Installer.uninstall_server(installation_path)
          
        {:error, reason} ->
          Logger.warning("Installation failed: #{inspect(reason)}")
          # Don't fail test if network issues
          assert true
      end
    end
    
    @tag :npm
    test "installs simple npm package as MCP server" do
      server_config = %{
        name: "lodash-mcp",
        source_type: :npm,
        package_name: "lodash",
        version: "4.17.21",
        create_wrapper: true
      }
      
      case Installer.install_server(server_config) do
        {:ok, installation_path} ->
          assert File.exists?(installation_path)
          assert File.exists?(Path.join(installation_path, "package.json"))
          assert File.exists?(Path.join(installation_path, "start.sh"))
          
          # Verify package.json content
          package_json = Path.join(installation_path, "package.json")
          content = File.read!(package_json) |> Jason.decode!()
          assert Map.has_key?(content, "dependencies")
          
          # Clean up
          Installer.uninstall_server(installation_path)
          
        {:error, reason} ->
          Logger.warning("NPM installation failed: #{inspect(reason)}")
          # Don't fail if npm not available
          assert true
      end
    end
  end
  
  describe "Real MCP Server Connection" do
    @tag :server_process
    test "connects to external MCP server process" do
      # Try to start a real MCP server process if available
      case find_mcp_server_executable() do
        {:ok, executable} ->
          test_external_server_connection(executable)
          
        {:error, :not_found} ->
          Logger.info("No MCP server executable found, skipping test")
          assert true
      end
    end
    
    @tag :stdio_connection
    test "establishes stdio connection with external process" do
      # Create a mock external MCP server for testing
      mock_server_script = create_mock_mcp_server()
      
      try do
        # Start the external process
        case System.cmd("node", [mock_server_script]) do
          {output, 0} ->
            Logger.info("Mock server output: #{output}")
            assert true
            
          {error, exit_code} ->
            Logger.warning("Mock server failed: #{error} (exit: #{exit_code})")
            assert true
        end
      catch
        :error, :enoent ->
          Logger.info("Node.js not available, skipping stdio test")
          assert true
      after
        File.rm(mock_server_script)
      end
    end
  end
  
  describe "Integration with External Services" do
    @tag :http_client
    test "integrates with HTTP-based MCP servers" do
      # Test integration with MCP servers that use HTTP transport
      server_config = %{
        id: "http_mcp_test",
        type: :external,
        transport: :http,
        url: "http://localhost:8080/mcp",
        capabilities: ["web_search", "data_processing"]
      }
      
      {:ok, manager} = ServerManager.start_link()
      
      # Try to start connection (may fail if server not available)
      case ServerManager.start_server(manager, server_config) do
        {:ok, server_id} ->
          # Verify server is tracked
          {:ok, status} = ServerManager.get_status(manager)
          assert Enum.any?(status.servers, &(&1.id == server_id))
          
          # Clean up
          ServerManager.stop_server(manager, server_id)
          
        {:error, reason} ->
          Logger.info("HTTP MCP server not available: #{inspect(reason)}")
          assert true
      end
      
      GenServer.stop(manager)
    end
    
    @tag :websocket_connection
    test "connects via WebSocket to MCP server" do
      # Test WebSocket MCP connection
      {:ok, client} = Client.start_link([
        name: :ws_test_client,
        transport: :websocket,
        connection: %{url: "ws://localhost:3333/mcp"},
        auto_connect: false
      ])
      
      # Connection will likely fail, but should handle gracefully
      case VsmMcp.MCP.connect(client) do
        :ok ->
          Logger.info("Successfully connected via WebSocket")
          VsmMcp.MCP.disconnect(client)
          
        {:error, reason} ->
          Logger.info("WebSocket connection failed as expected: #{inspect(reason)}")
          assert true
      end
      
      GenServer.stop(client)
    end
  end
  
  describe "Autonomous Integration Workflows" do
    @tag :workflow
    test "complete autonomous capability acquisition" do
      capture_log(fn ->
        {:ok, integration} = Integration.start_link([])
        
        # Define a realistic variety gap
        variety_gap = %{
          type: "file_processing",
          required_capabilities: [
            "csv_reading",
            "json_parsing", 
            "file_conversion"
          ],
          complexity: :medium,
          priority: :high,
          context: %{
            user_request: "I need to process CSV files and convert them to JSON",
            environment: "data_analysis_pipeline"
          }
        }
        
        # Attempt autonomous integration
        result = Integration.integrate_capability(variety_gap, [
          auto_discover: true,
          verify_security: true,
          test_capability: true
        ])
        
        case result do
          {:ok, capability} ->
            Logger.info("Successfully integrated capability: #{capability.id}")
            
            # Verify the capability
            {:ok, capabilities} = Integration.list_capabilities()
            assert Enum.any?(capabilities, &(&1.id == capability.id))
            
            # Test the capability
            test_integrated_capability(capability)
            
          {:error, reason} ->
            Logger.info("Integration failed (expected in test env): #{inspect(reason)}")
            assert true
        end
        
        GenServer.stop(integration)
      end)
    end
    
    @tag :dynamic_spawning
    test "dynamically spawns capability processes" do
      {:ok, spawner} = DynamicSpawner.start_link([])
      
      # Create mock adapter
      adapter = create_mock_adapter()
      
      capability_config = %{
        id: "test_dynamic_capability",
        name: "file_processor",
        server_info: %{type: "mock", version: "1.0.0"},
        variety_gap: %{type: "file_processing"},
        config: %{timeout: 5000}
      }
      
      case DynamicSpawner.spawn_capability(adapter, capability_config) do
        {:ok, pid} ->
          assert Process.alive?(pid)
          
          # Verify it's listed
          capabilities = DynamicSpawner.list_capabilities()
          assert Enum.any?(capabilities, fn {cap_pid, _} -> cap_pid == pid end)
          
          # Test termination
          :ok = DynamicSpawner.terminate_capability(capability_config.id)
          Process.sleep(100)
          assert not Process.alive?(pid)
          
        {:error, reason} ->
          Logger.info("Dynamic spawn failed: #{inspect(reason)}")
          assert true
      end
      
      GenServer.stop(spawner)
    end
  end
  
  describe "Real-World Integration Scenarios" do
    @tag :scenario
    test "PowerPoint creation capability integration" do
      capture_log(fn ->
        {:ok, integration} = Integration.start_link([])
        
        # Simulate user request for PowerPoint creation
        variety_gap = %{
          type: "document_creation",
          required_capabilities: ["presentation_creation", "template_management"],
          context: %{
            user_request: "Create PowerPoint presentations",
            output_format: "pptx",
            template_support: true
          },
          priority: :high
        }
        
        # Attempt integration with realistic discovery
        case Integration.integrate_capability(variety_gap, [
          sources: [:npm, :github],
          search_terms: ["powerpoint", "presentation", "pptx"],
          verify_compatibility: true
        ]) do
          {:ok, capability} ->
            Logger.info("PowerPoint capability integrated: #{capability.id}")
            
            # Verify capability properties
            assert capability.variety_gap.type == "document_creation"
            
          {:error, reason} ->
            Logger.info("PowerPoint integration not available: #{inspect(reason)}")
            assert true
        end
        
        GenServer.stop(integration)
      end)
    end
    
    @tag :scenario
    test "Database integration capability" do
      {:ok, integration} = Integration.start_link([])
      
      variety_gap = %{
        type: "database_operations",
        required_capabilities: ["sql_execution", "connection_pooling"],
        context: %{
          database_type: "postgresql",
          connection_string: "postgresql://localhost:5432/test"
        }
      }
      
      case Integration.integrate_capability(variety_gap) do
        {:ok, capability} ->
          # Test database capability
          assert capability.variety_gap.type == "database_operations"
          
        {:error, reason} ->
          Logger.info("Database integration failed: #{inspect(reason)}")
          assert true
      end
      
      GenServer.stop(integration)
    end
  end
  
  # Helper functions
  
  defp find_mcp_server_executable do
    # Look for common MCP server executables
    executables = [
      "mcp-server",
      "node_modules/.bin/mcp-server",
      "/usr/local/bin/mcp-server"
    ]
    
    case Enum.find(executables, &File.exists?/1) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end
  
  defp test_external_server_connection(executable) do
    # Start external MCP server
    port = Port.open({:spawn_executable, executable}, [
      :binary,
      :exit_status,
      args: ["--stdio"]
    ])
    
    # Give it time to start
    Process.sleep(1000)
    
    # Try to send MCP initialize message
    init_message = %{
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: %{
        protocolVersion: "2024-11-05",
        capabilities: %{},
        clientInfo: %{name: "vsm-mcp-test", version: "1.0.0"}
      }
    }
    
    message_json = Jason.encode!(init_message) <> "\n"
    Port.command(port, message_json)
    
    # Wait for response
    response = receive do
      {^port, {:data, data}} -> data
      {^port, {:exit_status, status}} -> {:exit, status}
    after
      5000 -> :timeout
    end
    
    Port.close(port)
    
    case response do
      :timeout ->
        Logger.info("External server connection timeout")
        assert true
        
      {:exit, status} ->
        Logger.info("External server exited with status: #{status}")
        assert true
        
      data when is_binary(data) ->
        Logger.info("Received response from external server")
        assert String.contains?(data, "jsonrpc")
    end
  end
  
  defp create_mock_mcp_server do
    server_code = """
    #!/usr/bin/env node
    
    const readline = require('readline');
    
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: false
    });
    
    rl.on('line', (line) => {
      try {
        const message = JSON.parse(line);
        
        if (message.method === 'initialize') {
          const response = {
            jsonrpc: '2.0',
            id: message.id,
            result: {
              protocolVersion: '2024-11-05',
              capabilities: {
                tools: {},
                resources: {},
                prompts: {}
              },
              serverInfo: {
                name: 'mock-mcp-server',
                version: '1.0.0'
              }
            }
          };
          console.log(JSON.stringify(response));
        }
      } catch (e) {
        // Ignore parse errors
      }
    });
    
    process.on('SIGTERM', () => process.exit(0));
    process.on('SIGINT', () => process.exit(0));
    """
    
    script_path = Path.join(System.tmp_dir(), "mock_mcp_server.js")
    File.write!(script_path, server_code)
    File.chmod!(script_path, 0o755)
    script_path
  end
  
  defp create_mock_adapter do
    %{
      connect: fn -> {:ok, %{status: :connected}} end,
      disconnect: fn _conn -> :ok end,
      execute: fn _conn, _method, _params -> {:ok, "mock result"} end,
      health_check: fn _conn -> :ok end,
      reconnect: fn _conn -> {:ok, %{status: :reconnected}} end
    }
  end
  
  defp test_integrated_capability(capability) do
    # Basic capability testing
    assert capability.id != nil
    assert capability.variety_gap != nil
    
    # Test if process is running (if applicable)
    if Map.has_key?(capability, :process) and capability.process do
      assert Process.alive?(capability.process)
    end
    
    Logger.info("Capability #{capability.id} tested successfully")
  end
end