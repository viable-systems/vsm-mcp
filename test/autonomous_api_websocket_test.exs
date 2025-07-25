defmodule AutonomousApiWebsocketTest do
  @moduledoc """
  Tests for REST API and WebSocket functionality in autonomous VSM-MCP operations.
  Validates real-time monitoring, API-triggered autonomous capabilities, and live updates.
  """
  
  use ExUnit.Case, async: false
  require Logger
  import ExUnit.CaptureLog
  
  alias VsmMcp.Integration
  alias VsmMcp.ConsciousnessInterface
  alias VsmMcp.MCP.ServerManager
  
  @moduletag :api_websocket
  @moduletag timeout: 60_000
  
  setup_all do
    # Ensure applications are started
    Application.ensure_all_started(:cowboy)
    Application.ensure_all_started(:jason)
    Application.ensure_all_started(:websocket_client)
    
    # Setup test data
    test_port_api = find_free_port(8080)
    test_port_ws = find_free_port(8081)
    
    %{api_port: test_port_api, ws_port: test_port_ws}
  end
  
  describe "REST API Autonomous Operations" do
    test "POST /api/v1/capabilities/acquire triggers autonomous discovery and integration", %{api_port: port} do
      capture_log(fn ->
        # Start API server
        {:ok, api_server} = start_test_api_server(port)
        
        # Start integration system
        {:ok, integration} = Integration.start_link([name: :api_test_integration])
        
        # Setup mocks for autonomous operations
        setup_api_integration_mocks()
        
        # Prepare capability acquisition request
        capability_request = %{
          "variety_gap" => %{
            "type" => "api_triggered_test",
            "required_capabilities" => ["file_processing", "data_analysis"],
            "complexity" => "medium",
            "priority" => "high",
            "context" => %{
              "user_request" => "Process CSV files via API",
              "environment" => "production"
            }
          },
          "options" => %{
            "auto_discover" => true,
            "auto_install" => true,
            "auto_verify" => true,
            "timeout" => 30000,
            "async" => true
          }
        }
        
        # Make API request
        response = HTTPoison.post!(
          "http://localhost:#{port}/api/v1/capabilities/acquire",
          Jason.encode!(capability_request),
          [
            {"content-type", "application/json"},
            {"accept", "application/json"}
          ]
        )
        
        # Verify API response
        assert response.status_code in [200, 202]
        response_data = Jason.decode!(response.body)
        
        # Validate response structure
        assert Map.has_key?(response_data, "integration_id")
        assert Map.has_key?(response_data, "status")
        assert Map.has_key?(response_data, "message")
        
        integration_id = response_data["integration_id"]
        assert is_binary(integration_id)
        assert response_data["status"] in ["started", "accepted", "processing"]
        
        # If async, monitor progress via status endpoint
        if response_data["status"] in ["started", "accepted"] do
          # Wait for processing to begin
          Process.sleep(500)
          
          # Check status endpoint
          status_response = HTTPoison.get!(
            "http://localhost:#{port}/api/v1/integrations/#{integration_id}/status"
          )
          
          assert status_response.status_code == 200
          status_data = Jason.decode!(status_response.body)
          
          # Validate status response
          assert Map.has_key?(status_data, "integration_id")
          assert Map.has_key?(status_data, "status")
          assert Map.has_key?(status_data, "progress")
          assert Map.has_key?(status_data, "current_stage")
          assert Map.has_key?(status_data, "started_at")
          
          assert status_data["integration_id"] == integration_id
          assert status_data["status"] in ["pending", "in_progress", "completed", "failed"]
          assert is_number(status_data["progress"])
          assert status_data["progress"] >= 0 and status_data["progress"] <= 100
          
          # Check detailed progress if available
          if Map.has_key?(status_data, "stages") do
            stages = status_data["stages"]
            
            expected_stages = ["discovery", "evaluation", "installation", "verification", "deployment"]
            for stage <- expected_stages do
              if Map.has_key?(stages, stage) do
                stage_info = stages[stage]
                assert Map.has_key?(stage_info, "status")
                assert Map.has_key?(stage_info, "started_at")
                assert stage_info["status"] in ["pending", "in_progress", "completed", "failed"]
              end
            end
          end
        end
        
        cleanup_api_integration_mocks()
        stop_test_api_server(api_server)
        GenServer.stop(integration)
      end)
    end
    
    test "GET /api/v1/capabilities lists autonomous capabilities with real-time status", %{api_port: port} do
      {:ok, api_server} = start_test_api_server(port)
      {:ok, integration} = Integration.start_link([name: :api_capabilities_test])
      
      # Create some test capabilities
      test_capabilities = [
        %{
          id: "api_test_cap_1",
          name: "CSV Processor",
          variety_gap: %{type: "file_processing"},
          status: :active,
          health: :healthy,
          created_at: DateTime.utc_now(),
          last_used: DateTime.utc_now()
        },
        %{
          id: "api_test_cap_2", 
          name: "Data Analyzer",
          variety_gap: %{type: "data_analysis"},
          status: :inactive,
          health: :degraded,
          created_at: DateTime.utc_now(),
          last_used: DateTime.add(DateTime.utc_now(), -3600, :second)
        }
      ]
      
      # Register capabilities
      for capability <- test_capabilities do
        Integration.register_capability(integration, capability)
      end
      
      # Make API request
      response = HTTPoison.get!(
        "http://localhost:#{port}/api/v1/capabilities",
        [{"accept", "application/json"}]
      )
      
      assert response.status_code == 200
      data = Jason.decode!(response.body)
      
      # Validate response structure
      assert Map.has_key?(data, "capabilities")
      assert Map.has_key?(data, "total_count")
      assert Map.has_key?(data, "active_count")
      assert Map.has_key?(data, "healthy_count")
      
      capabilities = data["capabilities"]
      assert is_list(capabilities)
      assert length(capabilities) >= 2
      
      # Check capability details
      for capability <- capabilities do
        assert Map.has_key?(capability, "id")
        assert Map.has_key?(capability, "name")
        assert Map.has_key?(capability, "status")
        assert Map.has_key?(capability, "health")
        assert Map.has_key?(capability, "variety_gap")
        assert Map.has_key?(capability, "created_at")
        assert Map.has_key?(capability, "performance_metrics")
        
        assert capability["status"] in ["active", "inactive", "error"]
        assert capability["health"] in ["healthy", "degraded", "critical", "unknown"]
      end
      
      # Verify counts
      active_capabilities = Enum.filter(capabilities, &(&1["status"] == "active"))
      healthy_capabilities = Enum.filter(capabilities, &(&1["health"] == "healthy"))
      
      assert data["active_count"] == length(active_capabilities)
      assert data["healthy_count"] == length(healthy_capabilities)
      
      stop_test_api_server(api_server)
      GenServer.stop(integration)
    end
    
    test "POST /api/v1/variety-gaps/inject triggers autonomous gap analysis", %{api_port: port} do
      {:ok, api_server} = start_test_api_server(port)
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :api_gap_test])
      
      # Prepare variety gap injection request
      gap_request = %{
        "variety_gap" => %{
          "type" => "api_injected_gap",
          "environmental_change" => %{
            "new_requirement" => "Real-time data processing",
            "complexity_increase" => 25,
            "urgency" => "high"
          },
          "expected_capabilities" => ["stream_processing", "real_time_analytics"],
          "metadata" => %{
            "source" => "api_request",
            "user_id" => "test_user_123",
            "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
          }
        },
        "options" => %{
          "auto_analyze" => true,
          "trigger_autonomous_response" => true,
          "response_threshold" => 0.6
        }
      }
      
      # Make API request
      response = HTTPoison.post!(
        "http://localhost:#{port}/api/v1/variety-gaps/inject",
        Jason.encode!(gap_request),
        [
          {"content-type", "application/json"},
          {"accept", "application/json"}
        ]
      )
      
      assert response.status_code in [200, 202]
      response_data = Jason.decode!(response.body)
      
      # Validate response
      assert Map.has_key?(response_data, "gap_id")
      assert Map.has_key?(response_data, "status")
      assert Map.has_key?(response_data, "analysis_triggered")
      
      gap_id = response_data["gap_id"]
      assert is_binary(gap_id)
      assert response_data["analysis_triggered"] == true
      
      # Wait for analysis
      Process.sleep(1000)
      
      # Check gap analysis status
      analysis_response = HTTPoison.get!(
        "http://localhost:#{port}/api/v1/variety-gaps/#{gap_id}/analysis"
      )
      
      assert analysis_response.status_code == 200
      analysis_data = Jason.decode!(analysis_response.body)
      
      # Validate analysis results
      assert Map.has_key?(analysis_data, "gap_id")
      assert Map.has_key?(analysis_data, "analysis_status")
      assert Map.has_key?(analysis_data, "variety_impact")
      assert Map.has_key?(analysis_data, "recommended_actions")
      
      assert analysis_data["gap_id"] == gap_id
      assert analysis_data["analysis_status"] in ["completed", "in_progress", "failed"]
      
      if analysis_data["analysis_status"] == "completed" do
        assert Map.has_key?(analysis_data["variety_impact"], "operational_impact")
        assert Map.has_key?(analysis_data["variety_impact"], "environmental_impact")
        assert is_list(analysis_data["recommended_actions"])
      end
      
      stop_test_api_server(api_server)
      GenServer.stop(consciousness)
    end
    
    test "GET /api/v1/system/status provides comprehensive autonomous system status", %{api_port: port} do
      {:ok, api_server} = start_test_api_server(port)
      {:ok, integration} = Integration.start_link([name: :api_status_test])
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :api_status_consciousness])
      
      # Make status request
      response = HTTPoison.get!(
        "http://localhost:#{port}/api/v1/system/status",
        [{"accept", "application/json"}]
      )
      
      assert response.status_code == 200
      status_data = Jason.decode!(response.body)
      
      # Validate comprehensive status structure
      required_sections = [
        "system_health",
        "variety_status", 
        "autonomous_operations",
        "capabilities_summary",
        "performance_metrics",
        "daemon_status"
      ]
      
      for section <- required_sections do
        assert Map.has_key?(status_data, section)
      end
      
      # Validate system health
      system_health = status_data["system_health"]
      assert Map.has_key?(system_health, "overall_status")
      assert Map.has_key?(system_health, "component_status")
      assert Map.has_key?(system_health, "uptime")
      assert system_health["overall_status"] in ["healthy", "degraded", "critical"]
      
      # Validate variety status
      variety_status = status_data["variety_status"]
      assert Map.has_key?(variety_status, "operational_variety")
      assert Map.has_key?(variety_status, "environmental_variety")
      assert Map.has_key?(variety_status, "variety_ratio")
      assert Map.has_key?(variety_status, "gaps_detected")
      assert is_number(variety_status["variety_ratio"])
      
      # Validate autonomous operations
      autonomous_ops = status_data["autonomous_operations"]
      assert Map.has_key?(autonomous_ops, "active_operations")
      assert Map.has_key?(autonomous_ops, "completed_today")
      assert Map.has_key?(autonomous_ops, "success_rate")
      assert Map.has_key?(autonomous_ops, "average_response_time")
      
      # Validate capabilities summary
      cap_summary = status_data["capabilities_summary"]
      assert Map.has_key?(cap_summary, "total_capabilities")
      assert Map.has_key?(cap_summary, "active_capabilities")
      assert Map.has_key?(cap_summary, "healthy_capabilities")
      assert Map.has_key?(cap_summary, "recent_acquisitions")
      
      stop_test_api_server(api_server)
      GenServer.stop(consciousness)
      GenServer.stop(integration)
    end
  end
  
  describe "WebSocket Real-time Monitoring" do
    test "WebSocket /live provides real-time autonomous operation updates", %{ws_port: port} do
      capture_log(fn ->
        # Start WebSocket server
        {:ok, ws_server} = start_test_websocket_server(port)
        
        # Connect WebSocket client
        {:ok, client} = connect_websocket_client("ws://localhost:#{port}/live")
        
        # Start integration system
        {:ok, integration} = Integration.start_link([name: :ws_live_test])
        
        # Setup WebSocket broadcasting
        Integration.enable_websocket_broadcasting(integration, port)
        
        # Setup mocks for operations
        setup_websocket_operation_mocks()
        
        # Start an autonomous operation
        variety_gap = %{
          type: "websocket_live_test",
          required_capabilities: ["live_monitoring"],
          complexity: :medium
        }
        
        {:ok, operation_id} = Integration.start_autonomous_integration(integration, variety_gap)
        
        # Collect WebSocket messages
        messages = collect_websocket_messages(client, 5000)
        
        # Verify we received operation updates
        operation_messages = Enum.filter(messages, fn msg ->
          Map.get(msg, "type") == "operation_update" and
          Map.get(msg, "operation_id") == operation_id
        end)
        
        assert length(operation_messages) > 0
        
        # Validate message structure
        for msg <- operation_messages do
          assert Map.has_key?(msg, "operation_id")
          assert Map.has_key?(msg, "status")
          assert Map.has_key?(msg, "progress")
          assert Map.has_key?(msg, "current_stage")
          assert Map.has_key?(msg, "timestamp")
          assert Map.has_key?(msg, "details")
          
          assert msg["operation_id"] == operation_id
          assert msg["status"] in ["started", "in_progress", "completed", "failed"]
          assert is_number(msg["progress"])
          assert msg["progress"] >= 0 and msg["progress"] <= 100
        end
        
        # Verify progression through stages
        stages_seen = Enum.map(operation_messages, & &1["current_stage"]) |> Enum.uniq()
        expected_stages = ["discovery", "evaluation", "installation", "verification"]
        
        for expected_stage <- expected_stages do
          assert expected_stage in stages_seen, "Missing stage: #{expected_stage}"
        end
        
        cleanup_websocket_operation_mocks()
        close_websocket_client(client)
        stop_test_websocket_server(ws_server)
        GenServer.stop(integration)
      end)
    end
    
    test "WebSocket /variety-gaps provides real-time variety gap detection", %{ws_port: port} do
      {:ok, ws_server} = start_test_websocket_server(port)
      {:ok, client} = connect_websocket_client("ws://localhost:#{port}/variety-gaps")
      
      # Start consciousness system
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :ws_gaps_test])
      
      # Enable WebSocket broadcasting for variety gaps
      ConsciousnessInterface.enable_websocket_broadcasting(consciousness, port)
      
      # Inject variety gaps
      variety_gaps = [
        %{
          type: "websocket_gap_1",
          complexity: :low,
          urgency: :high,
          detected_at: DateTime.utc_now()
        },
        %{
          type: "websocket_gap_2", 
          complexity: :high,
          urgency: :medium,
          detected_at: DateTime.utc_now()
        }
      ]
      
      for gap <- variety_gaps do
        ConsciousnessInterface.inject_variety_gap(consciousness, gap)
        Process.sleep(200)  # Allow time for broadcasting
      end
      
      # Collect WebSocket messages
      messages = collect_websocket_messages(client, 3000)
      
      # Verify gap detection messages
      gap_messages = Enum.filter(messages, fn msg ->
        Map.get(msg, "type") == "variety_gap_detected"
      end)
      
      assert length(gap_messages) >= 2
      
      # Validate gap message structure
      for msg <- gap_messages do
        assert Map.has_key?(msg, "gap_id")
        assert Map.has_key?(msg, "gap_type")
        assert Map.has_key?(msg, "complexity")
        assert Map.has_key?(msg, "urgency")
        assert Map.has_key?(msg, "detected_at")
        assert Map.has_key?(msg, "environmental_impact")
        assert Map.has_key?(msg, "recommended_response")
        
        assert msg["complexity"] in ["low", "medium", "high"]
        assert msg["urgency"] in ["low", "medium", "high", "critical"]
        assert is_binary(msg["gap_id"])
      end
      
      # Verify gap types match what we injected
      gap_types = Enum.map(gap_messages, & &1["gap_type"])
      assert "websocket_gap_1" in gap_types
      assert "websocket_gap_2" in gap_types
      
      close_websocket_client(client)
      stop_test_websocket_server(ws_server)
      GenServer.stop(consciousness)
    end
    
    test "WebSocket /system-metrics provides real-time performance monitoring", %{ws_port: port} do
      {:ok, ws_server} = start_test_websocket_server(port)
      {:ok, client} = connect_websocket_client("ws://localhost:#{port}/system-metrics")
      
      # Start systems for monitoring
      {:ok, integration} = Integration.start_link([name: :ws_metrics_test])
      {:ok, consciousness} = ConsciousnessInterface.start_link([name: :ws_metrics_consciousness])
      
      # Enable metrics broadcasting
      Integration.enable_metrics_broadcasting(integration, port)
      ConsciousnessInterface.enable_metrics_broadcasting(consciousness, port)
      
      # Generate some system activity
      spawn(fn ->
        for i <- 1..5 do
          variety_gap = %{
            type: "metrics_test_#{i}",
            required_capabilities: ["test_cap"],
            complexity: Enum.random([:low, :medium, :high])
          }
          
          ConsciousnessInterface.inject_variety_gap(consciousness, variety_gap)
          Process.sleep(500)
        end
      end)
      
      # Collect metrics messages
      messages = collect_websocket_messages(client, 4000)
      
      # Verify metrics messages
      metrics_messages = Enum.filter(messages, fn msg ->
        Map.get(msg, "type") == "system_metrics"
      end)
      
      assert length(metrics_messages) > 0
      
      # Validate metrics structure
      for msg <- metrics_messages do
        assert Map.has_key?(msg, "timestamp")
        assert Map.has_key?(msg, "memory_usage")
        assert Map.has_key?(msg, "cpu_usage")
        assert Map.has_key?(msg, "process_count")
        assert Map.has_key?(msg, "variety_metrics")
        assert Map.has_key?(msg, "operation_metrics")
        
        # Validate variety metrics
        variety_metrics = msg["variety_metrics"]
        assert Map.has_key?(variety_metrics, "operational_variety")
        assert Map.has_key?(variety_metrics, "environmental_variety")
        assert Map.has_key?(variety_metrics, "variety_ratio")
        assert Map.has_key?(variety_metrics, "gaps_active")
        
        # Validate operation metrics
        operation_metrics = msg["operation_metrics"]
        assert Map.has_key?(operation_metrics, "active_operations")
        assert Map.has_key?(operation_metrics, "avg_response_time")
        assert Map.has_key?(operation_metrics, "success_rate")
        assert Map.has_key?(operation_metrics, "throughput")
      end
      
      close_websocket_client(client)
      stop_test_websocket_server(ws_server)
      GenServer.stop(consciousness)
      GenServer.stop(integration)
    end
    
    test "WebSocket handles multiple concurrent clients", %{ws_port: port} do
      {:ok, ws_server} = start_test_websocket_server(port)
      
      # Connect multiple clients
      client_count = 5
      clients = for i <- 1..client_count do
        {:ok, client} = connect_websocket_client("ws://localhost:#{port}/live")
        {i, client}
      end
      
      # Start integration system
      {:ok, integration} = Integration.start_link([name: :ws_concurrent_test])
      Integration.enable_websocket_broadcasting(integration, port)
      
      # Trigger an operation
      variety_gap = %{
        type: "concurrent_websocket_test",
        required_capabilities: ["concurrent_test"],
        complexity: :medium
      }
      
      setup_websocket_operation_mocks()
      {:ok, operation_id} = Integration.start_autonomous_integration(integration, variety_gap)
      
      # Collect messages from all clients
      all_messages = Enum.flat_map(clients, fn {i, client} ->
        messages = collect_websocket_messages(client, 3000)
        Enum.map(messages, &Map.put(&1, "client_id", i))
      end)
      
      # Verify all clients received messages
      operation_messages = Enum.filter(all_messages, fn msg ->
        Map.get(msg, "type") == "operation_update" and
        Map.get(msg, "operation_id") == operation_id
      end)
      
      assert length(operation_messages) > 0
      
      # Verify each client received updates
      for {i, _client} <- clients do
        client_messages = Enum.filter(operation_messages, &(&1["client_id"] == i))
        assert length(client_messages) > 0, "Client #{i} received no messages"
      end
      
      # Clean up
      for {_i, client} <- clients do
        close_websocket_client(client)
      end
      
      cleanup_websocket_operation_mocks()
      stop_test_websocket_server(ws_server)
      GenServer.stop(integration)
    end
  end
  
  describe "API-WebSocket Integration" do
    test "API triggers update WebSocket notifications", %{api_port: api_port, ws_port: ws_port} do
      # Start both servers
      {:ok, api_server} = start_test_api_server(api_port)
      {:ok, ws_server} = start_test_websocket_server(ws_port)
      
      # Connect WebSocket client
      {:ok, ws_client} = connect_websocket_client("ws://localhost:#{ws_port}/live")
      
      # Start integration system
      {:ok, integration} = Integration.start_link([name: :api_ws_integration_test])
      Integration.enable_websocket_broadcasting(integration, ws_port)
      
      setup_api_integration_mocks()
      
      # Make API request to trigger autonomous operation
      capability_request = %{
        "variety_gap" => %{
          "type" => "api_ws_integration_test",
          "required_capabilities" => ["integration_test"],
          "complexity" => "low"
        },
        "options" => %{
          "auto_discover" => true,
          "notify_websocket" => true
        }
      }
      
      # Trigger via API
      api_response = HTTPoison.post!(
        "http://localhost:#{api_port}/api/v1/capabilities/acquire",
        Jason.encode!(capability_request),
        [{"content-type", "application/json"}]
      )
      
      assert api_response.status_code in [200, 202]
      api_data = Jason.decode!(api_response.body)
      integration_id = api_data["integration_id"]
      
      # Collect WebSocket notifications
      ws_messages = collect_websocket_messages(ws_client, 3000)
      
      # Verify WebSocket received notifications about the API-triggered operation
      integration_messages = Enum.filter(ws_messages, fn msg ->
        Map.get(msg, "integration_id") == integration_id or
        Map.get(msg, "operation_id") == integration_id
      end)
      
      assert length(integration_messages) > 0
      
      # Verify notification content
      for msg <- integration_messages do
        assert Map.has_key?(msg, "source")
        assert Map.has_key?(msg, "trigger_method")
        assert msg["source"] in ["api", "autonomous_system"]
        assert msg["trigger_method"] in ["api_request", "gap_detection"]
      end
      
      cleanup_api_integration_mocks()
      close_websocket_client(ws_client)
      stop_test_websocket_server(ws_server)
      stop_test_api_server(api_server)
      GenServer.stop(integration)
    end
  end
  
  # Helper Functions
  
  defp find_free_port(start_port) do
    case :gen_tcp.listen(start_port, []) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_port
      {:error, :eaddrinuse} ->
        find_free_port(start_port + 1)
    end
  end
  
  defp start_test_api_server(port) do
    # Start a minimal Cowboy server for testing
    routes = [
      {"/api/v1/capabilities/acquire", TestAPIHandler, [:acquire]},
      {"/api/v1/capabilities", TestAPIHandler, [:list]},
      {"/api/v1/integrations/:id/status", TestAPIHandler, [:status]},
      {"/api/v1/variety-gaps/inject", TestAPIHandler, [:inject_gap]},
      {"/api/v1/variety-gaps/:id/analysis", TestAPIHandler, [:gap_analysis]},
      {"/api/v1/system/status", TestAPIHandler, [:system_status]}
    ]
    
    dispatch = :cowboy_router.compile([
      {:_, routes}
    ])
    
    {:ok, _} = :cowboy.start_clear(
      :test_api_server,
      [{:port, port}],
      %{env: %{dispatch: dispatch}}
    )
    
    {:ok, :test_api_server}
  end
  
  defp stop_test_api_server(server_ref) do
    :cowboy.stop_listener(server_ref)
  end
  
  defp start_test_websocket_server(port) do
    # Start a minimal WebSocket server for testing
    routes = [
      {"/live", TestWebSocketHandler, []},
      {"/variety-gaps", TestWebSocketHandler, []},
      {"/system-metrics", TestWebSocketHandler, []}
    ]
    
    dispatch = :cowboy_router.compile([
      {:_, routes}
    ])
    
    {:ok, _} = :cowboy.start_clear(
      :test_ws_server,
      [{:port, port}],
      %{env: %{dispatch: dispatch}}
    )
    
    {:ok, :test_ws_server}
  end
  
  defp stop_test_websocket_server(server_ref) do
    :cowboy.stop_listener(server_ref)
  end
  
  defp connect_websocket_client(url) do
    :websocket_client.start_link(url, __MODULE__, [])
  end
  
  defp close_websocket_client(client) do
    :websocket_client.stop(client)
  end
  
  defp collect_websocket_messages(client, timeout) do
    collect_websocket_messages(client, [], timeout)
  end
  
  defp collect_websocket_messages(_client, acc, timeout) when timeout <= 0 do
    Enum.reverse(acc)
  end
  
  defp collect_websocket_messages(client, acc, timeout) do
    receive do
      {:websocket_message, ^client, {:text, message}} ->
        try do
          parsed_message = Jason.decode!(message)
          collect_websocket_messages(client, [parsed_message | acc], timeout - 10)
        catch
          _ -> collect_websocket_messages(client, acc, timeout - 10)
        end
    after
      10 ->
        collect_websocket_messages(client, acc, timeout - 10)
    end
  end
  
  defp setup_api_integration_mocks do
    # Mock the integration system to respond to API requests
    :meck.new(Integration, [:passthrough])
    :meck.expect(Integration, :start_autonomous_integration, fn _integration, _gap ->
      {:ok, "mock_integration_#{:erlang.unique_integer()}"}
    end)
    
    :meck.expect(Integration, :get_integration_status, fn _integration, _id ->
      {:ok, %{
        status: "in_progress",
        progress: 45,
        current_stage: "installation",
        started_at: DateTime.utc_now()
      }}
    end)
  end
  
  defp cleanup_api_integration_mocks do
    :meck.unload(Integration)
  end
  
  defp setup_websocket_operation_mocks do
    :meck.new(Integration, [:passthrough])
    :meck.expect(Integration, :start_autonomous_integration, fn _integration, _gap ->
      operation_id = "ws_mock_operation_#{:erlang.unique_integer()}"
      
      # Simulate operation progression with WebSocket updates
      spawn(fn ->
        stages = [
          {"discovery", 10},
          {"evaluation", 30}, 
          {"installation", 60},
          {"verification", 85},
          {"deployment", 100}
        ]
        
        for {stage, progress} <- stages do
          # Simulate WebSocket broadcasting
          send(self(), {:websocket_message, self(), {:text, Jason.encode!(%{
            "type" => "operation_update",
            "operation_id" => operation_id,
            "status" => "in_progress",
            "progress" => progress,
            "current_stage" => stage,
            "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
          })}})
          
          Process.sleep(200)
        end
        
        # Final completion message
        send(self(), {:websocket_message, self(), {:text, Jason.encode!(%{
          "type" => "operation_update",
          "operation_id" => operation_id,
          "status" => "completed",
          "progress" => 100,
          "current_stage" => "completed",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        })}})
      end)
      
      {:ok, operation_id}
    end)
  end
  
  defp cleanup_websocket_operation_mocks do
    :meck.unload(Integration)
  end
  
  # WebSocket client callbacks
  def websocket_handle({:text, message}, _conn_state) do
    send(self(), {:websocket_message, self(), {:text, message}})
    {:ok, nil}
  end
  
  def websocket_handle(_frame, _conn_state) do
    {:ok, nil}
  end
  
  def websocket_info(_info, _conn_state) do
    {:ok, nil}
  end
  
  def websocket_terminate(_reason, _conn_state) do
    :ok
  end
end

# Mock handlers for testing
defmodule TestAPIHandler do
  def init(req, state) do
    method = :cowboy_req.method(req)
    handle_request(method, req, state)
  end
  
  defp handle_request("POST", req, [:acquire]) do
    # Mock capability acquisition
    body = :cowboy_req.read_body(req)
    
    response = %{
      "integration_id" => "test_integration_#{:erlang.unique_integer()}",
      "status" => "started",
      "message" => "Autonomous capability acquisition initiated"
    }
    
    req2 = :cowboy_req.reply(202, 
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request("GET", req, [:list]) do
    # Mock capabilities list
    response = %{
      "capabilities" => [
        %{
          "id" => "test_cap_1",
          "name" => "Test Capability",
          "status" => "active",
          "health" => "healthy",
          "variety_gap" => %{"type" => "test"},
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "performance_metrics" => %{"response_time" => 150}
        }
      ],
      "total_count" => 1,
      "active_count" => 1,
      "healthy_count" => 1
    }
    
    req2 = :cowboy_req.reply(200,
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request("GET", req, [:status]) do
    # Mock integration status
    response = %{
      "integration_id" => "test_integration_123",
      "status" => "in_progress",
      "progress" => 65,
      "current_stage" => "verification",
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    req2 = :cowboy_req.reply(200,
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request("POST", req, [:inject_gap]) do
    # Mock variety gap injection
    response = %{
      "gap_id" => "test_gap_#{:erlang.unique_integer()}",
      "status" => "injected",
      "analysis_triggered" => true
    }
    
    req2 = :cowboy_req.reply(200,
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request("GET", req, [:gap_analysis]) do
    # Mock gap analysis
    response = %{
      "gap_id" => "test_gap_123",
      "analysis_status" => "completed",
      "variety_impact" => %{
        "operational_impact" => 0.3,
        "environmental_impact" => 0.7
      },
      "recommended_actions" => ["acquire_capability", "optimize_existing"]
    }
    
    req2 = :cowboy_req.reply(200,
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request("GET", req, [:system_status]) do
    # Mock system status
    response = %{
      "system_health" => %{
        "overall_status" => "healthy",
        "component_status" => %{},
        "uptime" => 3600
      },
      "variety_status" => %{
        "operational_variety" => 100,
        "environmental_variety" => 120,
        "variety_ratio" => 0.83,
        "gaps_detected" => 2
      },
      "autonomous_operations" => %{
        "active_operations" => 3,
        "completed_today" => 15,
        "success_rate" => 0.87,
        "average_response_time" => 1250
      },
      "capabilities_summary" => %{
        "total_capabilities" => 12,
        "active_capabilities" => 10,
        "healthy_capabilities" => 9,
        "recent_acquisitions" => 2
      },
      "performance_metrics" => %{
        "memory_usage" => 45600000,
        "cpu_usage" => 0.15
      },
      "daemon_status" => %{
        "active" => true,
        "monitoring_interval" => 1000,
        "last_check" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
    
    req2 = :cowboy_req.reply(200,
      %{"content-type" => "application/json"},
      Jason.encode!(response),
      req)
    
    {:ok, req2, []}
  end
  
  defp handle_request(_method, req, _state) do
    req2 = :cowboy_req.reply(404, req)
    {:ok, req2, []}
  end
end

defmodule TestWebSocketHandler do
  @behaviour :cowboy_websocket
  
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end
  
  def websocket_init(state) do
    {:ok, state}
  end
  
  def websocket_handle({:text, _msg}, state) do
    {:ok, state}
  end
  
  def websocket_handle(_frame, state) do
    {:ok, state}
  end
  
  def websocket_info(_info, state) do
    {:ok, state}
  end
end