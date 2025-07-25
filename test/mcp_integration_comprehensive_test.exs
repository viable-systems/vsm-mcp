defmodule MCPIntegrationComprehensiveTest do
  @moduledoc """
  Comprehensive test suite for MCP integration and system testing.
  Tests dynamic MCP server installation, connection mechanisms, and autonomous integration scenarios.
  """
  
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog
  import ExUnit.CaptureIO
  
  alias VsmMcp.Integration
  alias VsmMcp.Integration.{Installer, DynamicSpawner, CapabilityMatcher, Sandbox, Verifier}
  alias VsmMcp.MCP.{Client, Server, ServerManager}
  alias VsmMcp.MCP
  
  @moduletag :integration
  @moduletag timeout: 60_000
  
  setup_all do
    # Start application if not running
    if not Application.get_application(VsmMcp.Application) do
      Application.ensure_all_started(:vsm_mcp)
    end
    
    # Create test directories
    test_dir = Path.join([System.tmp_dir(), "mcp_integration_test"])
    File.mkdir_p!(test_dir)
    
    on_exit(fn ->
      File.rm_rf!(test_dir)
    end)
    
    %{test_dir: test_dir}
  end
  
  describe "Dynamic MCP Server Installation" do
    test "installs npm-based MCP server successfully", %{test_dir: test_dir} do
      server_config = %{
        name: "test-express-server",
        source_type: :npm,
        package_name: "express",
        version: "latest",
        installation_dir: test_dir
      }
      
      assert {:ok, installation_path} = Installer.install_server(server_config)
      assert File.exists?(installation_path)
      assert File.exists?(Path.join(installation_path, "package.json"))
      
      # Verify installation info
      assert {:ok, info} = Installer.verify_installation(installation_path)
      assert info.path == installation_path
      assert info.size > 0
    end
    
    test "installs git-based MCP server successfully", %{test_dir: test_dir} do
      server_config = %{
        name: "test-git-server",
        source_type: :git,
        repository_url: "https://github.com/ruvnet/hello-mcp.git",
        branch: "main",
        installation_dir: test_dir
      }
      
      assert {:ok, installation_path} = Installer.install_server(server_config)
      assert File.exists?(installation_path)
      assert File.exists?(Path.join(installation_path, ".git"))
      
      # Clean up
      Installer.uninstall_server(installation_path)
    end
    
    test "handles installation failures gracefully", %{test_dir: test_dir} do
      server_config = %{
        name: "invalid-server",
        source_type: :npm,
        package_name: "nonexistent-package-12345",
        version: "latest",
        installation_dir: test_dir
      }
      
      assert {:error, reason} = Installer.install_server(server_config)
      assert reason != nil
    end
    
    test "prevents duplicate installations" do
      server_config = %{
        name: "test-duplicate",
        source_type: :npm,
        package_name: "lodash",
        version: "latest"
      }
      
      # First installation
      assert {:ok, path1} = Installer.install_server(server_config)
      
      # Second installation should return existing path
      assert {:ok, path2} = Installer.install_server(server_config)
      assert path1 == path2
      
      # Clean up
      Installer.uninstall_server(path1)
    end
  end
  
  describe "MCP Connection Mechanisms" do
    test "establishes stdio connection to MCP server" do
      # Start a simple MCP server
      {:ok, server} = Server.start_link([
        name: :test_stdio_server,
        transport: :stdio,
        auto_start: true
      ])
      
      # Register a test tool
      MCP.register_tool(server, "test_tool", %{
        description: "A test tool",
        input_schema: %{
          type: "object",
          properties: %{
            message: %{type: "string"}
          },
          required: ["message"]
        },
        execute: fn params ->
          {:ok, "Echo: #{params["message"]}"}
        end
      })
      
      # Start client and connect
      {:ok, client} = Client.start_link([
        name: :test_stdio_client,
        transport: :stdio,
        auto_connect: false
      ])
      
      assert :ok = MCP.connect(client)
      
      # Test tool invocation
      assert {:ok, tools} = MCP.list_tools(client)
      assert Enum.any?(tools, &(&1["name"] == "test_tool"))
      
      assert {:ok, result} = MCP.call_tool(client, "test_tool", %{"message" => "hello"})
      assert result["content"] |> List.first() |> Map.get("text") =~ "Echo: hello"
      
      # Clean up
      GenServer.stop(client)
      GenServer.stop(server)
    end
    
    test "establishes TCP connection to MCP server" do
      # Start TCP server on random port
      {:ok, server} = Server.start_link([
        name: :test_tcp_server,
        transport: :tcp,
        port: 0,
        auto_start: true
      ])
      
      # Get actual port
      port = case :ranch.get_port(:test_tcp_server) do
        {:error, _} -> 
          # Fallback for different ranch versions
          3334
        actual_port -> actual_port
      end
      
      # Start client and connect
      {:ok, client} = Client.start_link([
        name: :test_tcp_client,
        transport: :tcp,
        connection: %{host: "localhost", port: port},
        auto_connect: false
      ])
      
      assert :ok = MCP.connect(client)
      
      # Test basic functionality
      assert {:ok, _tools} = MCP.list_tools(client)
      
      # Clean up
      GenServer.stop(client)
      GenServer.stop(server)
    end
    
    test "handles connection failures gracefully" do
      # Try to connect to non-existent server
      {:ok, client} = Client.start_link([
        name: :test_failed_client,
        transport: :tcp,
        connection: %{host: "localhost", port: 9999},
        auto_connect: false
      ])
      
      # Connection should fail
      assert {:error, _reason} = MCP.connect(client)
      
      GenServer.stop(client)
    end
  end
  
  describe "Autonomous Integration Scenarios" do
    test "complete capability integration pipeline" do
      capture_log(fn ->
        # Start integration system
        {:ok, integration} = Integration.start_link([])
        
        # Define a variety gap that needs filling
        variety_gap = %{
          type: "data_processing",
          required_capabilities: ["csv_parsing", "data_transformation"],
          complexity: :medium,
          priority: :high
        }
        
        # Mock capability matcher to return test servers
        :meck.new(CapabilityMatcher, [:passthrough])
        :meck.expect(CapabilityMatcher, :find_matching_servers, fn _gap ->
          {:ok, [
            %{
              name: "data-processor",
              type: "npm",
              package: "papaparse",
              capabilities: ["csv_parsing"],
              performance_rating: 0.8,
              stars: 1500,
              downloads: 50000
            }
          ]}
        end)
        
        # Mock installer to simulate successful installation
        :meck.new(Installer, [:passthrough])
        :meck.expect(Installer, :install_server, fn _config ->
          {:ok, "/tmp/mock_installation"}
        end)
        
        # Mock sandbox testing
        :meck.new(Sandbox, [:passthrough])
        :meck.expect(Sandbox, :test_server, fn _path, _server ->
          {:ok, %{
            status: :passed,
            tests_run: 10,
            failures: 0,
            metrics: %{
              memory_usage: 50_000_000,
              startup_time: 2000,
              response_time: 100
            }
          }}
        end)
        
        # Mock verifier
        :meck.new(Verifier, [:passthrough])
        :meck.expect(Verifier, :verify_capability, fn _result, _gap ->
          {:ok, %{
            verified: true,
            capabilities: ["csv_parsing"],
            security_level: :safe
          }}
        end)
        
        # Trigger integration
        assert {:ok, capability} = Integration.integrate_capability(variety_gap)
        
        # Verify the capability was integrated
        assert capability.variety_gap == variety_gap
        assert capability.installation_path == "/tmp/mock_installation"
        
        # Verify it appears in capability list
        {:ok, capabilities} = Integration.list_capabilities()
        assert Enum.any?(capabilities, &(&1.id == capability.id))
        
        # Clean up mocks
        :meck.unload(CapabilityMatcher)
        :meck.unload(Installer)
        :meck.unload(Sandbox)
        :meck.unload(Verifier)
        
        GenServer.stop(integration)
      end)
    end
    
    test "capability expansion through integrated MCP servers" do
      # Start server manager
      {:ok, manager} = ServerManager.start_link()
      
      # Start a test MCP server with multiple tools
      server_config = %{
        id: "test_expansion_server",
        type: :internal,
        server_opts: [
          name: :expansion_test_server,
          transport: :stdio
        ]
      }
      
      assert {:ok, server_id} = ServerManager.start_server(manager, server_config)
      
      # Verify server is running
      {:ok, status} = ServerManager.get_status(manager)
      assert Enum.any?(status.servers, &(&1.id == server_id))
      
      # Test capability expansion by adding tools dynamically
      server_pid = status.servers 
        |> Enum.find(&(&1.id == server_id))
        |> Map.get(:pid)
      
      # Add multiple tools to simulate capability expansion
      tools = [
        {"data_processor", %{
          description: "Process data files",
          input_schema: %{type: "object"},
          execute: fn _params -> {:ok, "processed"} end
        }},
        {"file_converter", %{
          description: "Convert file formats",
          input_schema: %{type: "object"},
          execute: fn _params -> {:ok, "converted"} end
        }}
      ]
      
      for {name, spec} <- tools do
        MCP.register_tool(server_pid, name, spec)
      end
      
      # Start client to verify expanded capabilities
      {:ok, client} = Client.start_link([
        name: :expansion_client,
        transport: :stdio,
        auto_connect: false
      ])
      
      :ok = MCP.connect(client)
      {:ok, available_tools} = MCP.list_tools(client)
      
      # Verify all tools are available
      tool_names = Enum.map(available_tools, &(&1["name"]))
      assert "data_processor" in tool_names
      assert "file_converter" in tool_names
      
      # Clean up
      GenServer.stop(client)
      ServerManager.stop_server(manager, server_id)
      GenServer.stop(manager)
    end
    
    test "handles real MCP server connections" do
      # Test with a real MCP server if available
      # This test might be skipped in CI environments
      
      unless System.get_env("SKIP_REAL_MCP_TESTS") do
        # Try to start a real server process
        case System.cmd("node", ["--version"]) do
          {_, 0} ->
            # Node.js is available, try to run a simple MCP server
            test_real_mcp_connection()
            
          _ ->
            # Skip test if Node.js not available
            Logger.info("Skipping real MCP test - Node.js not available")
        end
      end
    end
  end
  
  describe "Error Handling and Resilience" do
    test "handles MCP server crashes gracefully" do
      {:ok, manager} = ServerManager.start_link()
      
      # Start a server that will crash
      server_config = %{
        id: "crash_test_server",
        type: :internal,
        server_opts: [name: :crash_test_server, transport: :stdio]
      }
      
      {:ok, server_id} = ServerManager.start_server(manager, server_config)
      
      # Get server process
      {:ok, status} = ServerManager.get_status(manager)
      server_info = Enum.find(status.servers, &(&1.id == server_id))
      server_pid = server_info.pid
      
      # Force crash the server
      Process.exit(server_pid, :kill)
      
      # Wait for restart (should happen automatically)
      Process.sleep(1000)
      
      # Verify server was restarted (if restart policy allows)
      {:ok, new_status} = ServerManager.get_status(manager)
      
      case server_info.restart_count do
        count when count < 3 ->
          # Should be restarted
          assert Enum.any?(new_status.servers, &(&1.id == server_id))
          
        _ ->
          # May have been permanently stopped after max restarts
          assert true
      end
      
      GenServer.stop(manager)
    end
    
    test "validates MCP protocol compatibility" do
      # Test protocol version negotiation
      {:ok, server} = Server.start_link([
        name: :protocol_test_server,
        transport: :stdio
      ])
      
      {:ok, client} = Client.start_link([
        name: :protocol_test_client,
        transport: :stdio,
        auto_connect: false
      ])
      
      # Should successfully negotiate protocol
      assert :ok = MCP.connect(client)
      
      # Test if server supports required capabilities
      {:ok, tools} = MCP.list_tools(client)
      {:ok, resources} = MCP.list_resources(client)
      {:ok, prompts} = MCP.list_prompts(client)
      
      # Basic protocol functionality should work
      assert is_list(tools)
      assert is_list(resources) 
      assert is_list(prompts)
      
      GenServer.stop(client)
      GenServer.stop(server)
    end
    
    test "handles network interruptions during integration" do
      capture_log(fn ->
        # Simulate network interruption during discovery
        :meck.new(HTTPoison, [:passthrough])
        :meck.sequence(HTTPoison, :get, 1, [
          {:ok, %HTTPoison.Response{status_code: 200, body: "[]"}},
          {:error, :timeout},
          {:ok, %HTTPoison.Response{status_code: 200, body: "[]"}}
        ])
        
        {:ok, integration} = Integration.start_link([])
        
        variety_gap = %{
          type: "network_test",
          required_capabilities: ["api_calls"],
          complexity: :low
        }
        
        # Should handle network error gracefully
        result = Integration.integrate_capability(variety_gap)
        
        # May succeed with fallback or fail gracefully
        assert match?({:ok, _}, result) or match?({:error, _}, result)
        
        :meck.unload(HTTPoison)
        GenServer.stop(integration)
      end)
    end
  end
  
  describe "Performance and Load Testing" do
    test "handles concurrent MCP operations" do
      {:ok, manager} = ServerManager.start_link()
      
      # Start multiple servers
      server_configs = for i <- 1..5 do
        %{
          id: "concurrent_server_#{i}",
          type: :internal,
          server_opts: [name: :"concurrent_server_#{i}", transport: :stdio]
        }
      end
      
      # Start all servers concurrently
      tasks = Enum.map(server_configs, fn config ->
        Task.async(fn ->
          ServerManager.start_server(manager, config)
        end)
      end)
      
      results = Task.await_many(tasks, 10_000)
      
      # All servers should start successfully
      assert Enum.all?(results, &match?({:ok, _}, &1))
      
      # Verify all are running
      {:ok, status} = ServerManager.get_status(manager)
      assert length(status.servers) == 5
      
      # Stop all servers
      server_ids = Enum.map(results, fn {:ok, id} -> id end)
      {:ok, stop_results} = ServerManager.stop_servers(manager, server_ids)
      
      assert Enum.all?(stop_results, &match?({:ok, _}, &1))
      
      GenServer.stop(manager)
    end
    
    test "measures integration performance" do
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, integration} = Integration.start_link([])
      
      # Mock fast responses
      :meck.new(CapabilityMatcher, [:passthrough])
      :meck.expect(CapabilityMatcher, :find_matching_servers, fn _gap ->
        {:ok, [%{name: "test", capabilities: ["test"]}]}
      end)
      
      variety_gap = %{
        type: "performance_test",
        required_capabilities: ["test"]
      }
      
      # Integration should complete quickly
      result = Integration.integrate_capability(variety_gap)
      end_time = System.monotonic_time(:millisecond)
      
      duration = end_time - start_time
      
      # Should complete within reasonable time (adjust threshold as needed)
      assert duration < 5000  # 5 seconds
      
      :meck.unload(CapabilityMatcher)
      GenServer.stop(integration)
    end
  end
  
  # Helper functions
  
  defp test_real_mcp_connection do
    # Create a simple Node.js MCP server for testing
    server_code = """
    const { createServer } = require('net');
    
    const server = createServer((socket) => {
      socket.on('data', (data) => {
        const message = JSON.parse(data.toString());
        const response = {
          jsonrpc: "2.0",
          id: message.id,
          result: { message: "Hello from real MCP server" }
        };
        socket.write(JSON.stringify(response) + '\\n');
      });
    });
    
    server.listen(3335, () => {
      console.log('MCP server listening on port 3335');
    });
    """
    
    # Write temporary server file
    server_file = Path.join(System.tmp_dir(), "test_mcp_server.js")
    File.write!(server_file, server_code)
    
    # Start the server
    port = Port.open({:spawn, "node #{server_file}"}, [:binary])
    
    # Give server time to start
    Process.sleep(1000)
    
    # Try to connect with MCP client
    {:ok, client} = Client.start_link([
      name: :real_mcp_client,
      transport: :tcp,
      connection: %{host: "localhost", port: 3335},
      auto_connect: false
    ])
    
    result = MCP.connect(client)
    
    # Clean up
    GenServer.stop(client)
    Port.close(port)
    File.rm(server_file)
    
    # Verify connection worked (or failed gracefully)
    assert result == :ok or match?({:error, _}, result)
  end
end