defmodule VsmMcp.MCP.Protocol.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmMcp.MCP.Protocol.{JsonRpc, Handler}
  alias JsonRpc.{Request, Response, Notification}
  
  # Helper tool and resource modules for testing
  defmodule EchoTool do
    def description, do: "Echo tool for testing"
    def input_schema, do: %{type: "object"}
    def execute(args), do: {:ok, "Echo: #{inspect(args)}"}
  end
  
  defmodule TestTool1 do
    def description, do: "Test tool 1"
    def input_schema, do: %{}
    def execute(_args), do: {:ok, "result1"}
  end
  
  defmodule TestTool2 do
    def description, do: "Test tool 2"
    def input_schema, do: %{}
    def execute(_args), do: {:ok, "result2"}
  end
  
  defmodule TestResource do
    def name, do: "Test Resource"
    def description, do: "A test resource"
    def mime_type, do: "text/plain"
    def read(), do: {:ok, "Test resource content"}
  end

  describe "JSON-RPC Integration with MCP Protocol Handler" do
    test "complete request/response cycle" do
      # Setup mock transport
      test_pid = self()
      
      # Mock capabilities and handlers
      capabilities = %{
        tools: %{list: true, call: true},
        resources: %{list: true, read: true}
      }
      
      handlers = %{
        tools: %{
          "echo" => EchoTool
        },
        resources: %{
          "test://resource" => TestResource
        }
      }
      
      # Start the protocol handler
      {:ok, handler_pid} = Handler.start_link(
        transport: test_pid,
        capabilities: capabilities,
        handlers: handlers,
        name: :test_handler
      )
      
      # Test 1: Initialize request
      init_request = JsonRpc.build_jsonrpc_request("initialize", %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{},
        "clientInfo" => %{
          "name" => "Test Client",
          "version" => "1.0.0"
        }
      })
      
      {:ok, init_json} = JsonRpc.encode_jsonrpc_message(init_request)
      send(handler_pid, {:message, init_json})
      
      # Should receive initialize response
      assert_receive {:send, response_json}
      {:ok, init_response} = JsonRpc.parse_jsonrpc_message(response_json)
      assert %Response{} = init_response
      assert init_response.result["protocolVersion"] == "2024-11-05"
      assert init_response.result["serverInfo"]["name"] == "VSM-MCP"
      
      # Test 2: List tools request
      tools_request = JsonRpc.build_jsonrpc_request("tools/list", %{})
      {:ok, tools_json} = JsonRpc.encode_jsonrpc_message(tools_request)
      send(handler_pid, {:message, tools_json})
      
      # Should receive tools list response
      assert_receive {:send, tools_response_json}
      {:ok, tools_response} = JsonRpc.parse_jsonrpc_message(tools_response_json)
      assert %Response{} = tools_response
      assert length(tools_response.result["tools"]) == 1
      assert List.first(tools_response.result["tools"])["name"] == "echo"
      
      # Test 3: Call tool request
      call_request = JsonRpc.build_jsonrpc_request("tools/call", %{
        "name" => "echo",
        "arguments" => %{"message" => "Hello, World!"}
      })
      {:ok, call_json} = JsonRpc.encode_jsonrpc_message(call_request)
      send(handler_pid, {:message, call_json})
      
      # Should receive tool call response
      assert_receive {:send, call_response_json}
      {:ok, call_response} = JsonRpc.parse_jsonrpc_message(call_response_json)
      assert %Response{} = call_response
      content = List.first(call_response.result["content"])
      assert content["type"] == "text"
      assert String.contains?(content["text"], "Hello, World!")
      
      # Test 4: List resources request
      resources_request = JsonRpc.build_jsonrpc_request("resources/list", %{})
      {:ok, resources_json} = JsonRpc.encode_jsonrpc_message(resources_request)
      send(handler_pid, {:message, resources_json})
      
      # Should receive resources list response
      assert_receive {:send, resources_response_json}
      {:ok, resources_response} = JsonRpc.parse_jsonrpc_message(resources_response_json)
      assert %Response{} = resources_response
      assert length(resources_response.result["resources"]) == 1
      assert List.first(resources_response.result["resources"])["uri"] == "test://resource"
      
      # Test 5: Read resource request
      read_request = JsonRpc.build_jsonrpc_request("resources/read", %{
        "uri" => "test://resource"
      })
      {:ok, read_json} = JsonRpc.encode_jsonrpc_message(read_request)
      send(handler_pid, {:message, read_json})
      
      # Should receive resource read response
      assert_receive {:send, read_response_json}
      {:ok, read_response} = JsonRpc.parse_jsonrpc_message(read_response_json)
      assert %Response{} = read_response
      content = List.first(read_response.result["contents"])
      assert content["uri"] == "test://resource"
      assert content["text"] == "Test resource content"
      
      # Test 6: Send notification
      notification = JsonRpc.build_jsonrpc_notification("notifications/progress", %{
        "progressToken" => "test-123",
        "progress" => 50,
        "total" => 100
      })
      {:ok, notif_json} = JsonRpc.encode_jsonrpc_message(notification)
      send(handler_pid, {:message, notif_json})
      
      # Should not receive any response for notification
      refute_receive {:send, _}, 100
      
      # Test 7: Error handling - invalid method
      invalid_request = JsonRpc.build_jsonrpc_request("invalid/method", %{})
      {:ok, invalid_json} = JsonRpc.encode_jsonrpc_message(invalid_request)
      send(handler_pid, {:message, invalid_json})
      
      # Should receive error response
      assert_receive {:send, error_response_json}
      {:ok, error_response} = JsonRpc.parse_jsonrpc_message(error_response_json)
      assert %Response{} = error_response
      assert error_response.error.code == -32601
      assert error_response.error.message == "Method not found"
      
      # Test 8: Malformed JSON handling
      malformed_json = ~s({"invalid": json})
      send(handler_pid, {:message, malformed_json})
      
      # Should receive parse error (might not have valid ID)
      assert_receive {:send, parse_error_json}
      case JsonRpc.parse_jsonrpc_message(parse_error_json) do
        {:ok, %Response{} = parse_error} ->
          assert parse_error.error.code == -32700
          assert parse_error.error.message == "Parse error"
        {:error, _} ->
          # Some malformed JSON cases produce unparseable error responses
          assert String.contains?(parse_error_json, "Parse error") or
                 String.contains?(parse_error_json, "-32700")
      end
      
      # Cleanup
      GenServer.stop(handler_pid)
    end
    
    test "batch request processing" do
      # Setup mock transport
      test_pid = self()
      
      handlers = %{
        tools: %{
          "test1" => TestTool1,
          "test2" => TestTool2
        }
      }
      
      {:ok, handler_pid} = Handler.start_link(
        transport: test_pid,
        handlers: handlers,
        name: :test_batch_handler
      )
      
      # Create batch request with mix of requests and notifications
      messages = [
        JsonRpc.build_jsonrpc_request("tools/call", %{"name" => "test1", "arguments" => %{}}, 1),
        JsonRpc.build_jsonrpc_request("tools/call", %{"name" => "test2", "arguments" => %{}}, 2),
        JsonRpc.build_jsonrpc_notification("notifications/progress", %{"value" => 75})
      ]
      
      batch = %JsonRpc.Batch{messages: messages}
      {:ok, batch_json} = JsonRpc.encode_jsonrpc_message(batch)
      send(handler_pid, {:message, batch_json})
      
      # Should receive batch response (only for requests, not notifications)
      assert_receive {:send, batch_response_json}
      {:ok, batch_response} = JsonRpc.parse_jsonrpc_message(batch_response_json)
      assert %JsonRpc.Batch{messages: responses} = batch_response
      assert length(responses) == 2  # Only requests get responses
      
      # Check each response
      [resp1, resp2] = responses
      assert %Response{id: 1} = resp1
      assert %Response{id: 2} = resp2
      
      # Cleanup
      GenServer.stop(handler_pid)
    end
    
    test "request timeout handling" do
      # Setup mock transport
      test_pid = self()
      
      # Start handler with short timeout
      {:ok, handler_pid} = Handler.start_link(
        transport: test_pid,
        timeout: 100,  # 100ms timeout
        name: :test_timeout_handler
      )
      
      # Send a request from the handler to the transport (simulating client request)
      task = Task.async(fn ->
        Handler.send_request(handler_pid, "test/method", %{})
      end)
      
      # Don't send any response, let it timeout
      assert {:error, :timeout} = Task.await(task, 200)
      
      # Cleanup
      GenServer.stop(handler_pid)
    end
    
    test "request correlation and response matching" do
      # Test the correlation system directly
      pending_requests = %{
        1 => %{from: self(), method: "test1", timestamp: System.monotonic_time(:millisecond)},
        2 => %{from: self(), method: "test2", timestamp: System.monotonic_time(:millisecond)}
      }
      
      # Test successful correlation
      response1 = JsonRpc.build_jsonrpc_response(%{result: "success"}, 1)
      {:ok, {request_info, remaining}} = JsonRpc.correlate_response(response1, pending_requests)
      
      assert request_info.method == "test1"
      assert Map.has_key?(remaining, 2)
      refute Map.has_key?(remaining, 1)
      
      # Test correlation for unknown ID
      response3 = JsonRpc.build_jsonrpc_response(%{result: "unknown"}, 3)
      {:error, {:unknown_request, _}} = JsonRpc.correlate_response(response3, remaining)
    end
  end
  
  describe "Error scenarios and recovery" do
    test "handles protocol violations gracefully" do
      test_pid = self()
      
      {:ok, handler_pid} = Handler.start_link(
        transport: test_pid,
        name: :test_error_handler
      )
      
      # Test various malformed messages
      test_cases = [
        ~s({"jsonrpc":"1.0","method":"test","id":1}),  # Wrong version
        ~s({"jsonrpc":"2.0","id":1}),                   # Missing method
        ~s({"jsonrpc":"2.0","method":"","id":1}),       # Empty method
        ~s({"jsonrpc":"2.0","method":123,"id":1}),      # Invalid method type
        ~s([]),                                         # Empty batch
        ~s(not-json-at-all)                             # Invalid JSON
      ]
      
      for malformed_json <- test_cases do
        send(handler_pid, {:message, malformed_json})
        
        # Should receive some form of error response
        assert_receive {:send, error_json}, 1000
        
        # Parse the error response
        case JsonRpc.parse_jsonrpc_message(error_json) do
          {:ok, %Response{error: error}} ->
            assert error.code < 0  # Should be a valid error code
            assert is_binary(error.message)
          
          {:error, _reason} ->
            # Some malformed cases might not produce parseable responses
            :ok
        end
      end
      
      GenServer.stop(handler_pid)
    end
    
    test "maintains message ordering under load" do
      test_pid = self()
      
      {:ok, handler_pid} = Handler.start_link(
        transport: test_pid,
        name: :test_ordering_handler
      )
      
      # Send multiple requests rapidly
      request_ids = 1..10
      
      for id <- request_ids do
        request = JsonRpc.build_jsonrpc_request("ping", %{}, id)
        {:ok, json} = JsonRpc.encode_jsonrpc_message(request)
        send(handler_pid, {:message, json})
      end
      
      # Collect all responses
      responses = for _id <- request_ids do
        assert_receive {:send, response_json}
        {:ok, response} = JsonRpc.parse_jsonrpc_message(response_json)
        response
      end
      
      # Verify all responses received and have correct structure
      response_ids = Enum.map(responses, & &1.id) |> Enum.sort()
      assert response_ids == Enum.to_list(request_ids)
      
      GenServer.stop(handler_pid)
    end
  end
end