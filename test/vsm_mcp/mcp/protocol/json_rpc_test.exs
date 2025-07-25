defmodule VsmMcp.MCP.Protocol.JsonRpcTest do
  use ExUnit.Case, async: true
  
  alias VsmMcp.MCP.Protocol.JsonRpc
  alias JsonRpc.{Request, Response, Notification, Error, Batch}

  describe "build_jsonrpc_request/3" do
    test "creates a valid request with auto-generated ID" do
      request = JsonRpc.build_jsonrpc_request("test/method", %{param: "value"})
      
      assert %Request{} = request
      assert request.jsonrpc == "2.0"
      assert request.method == "test/method"
      assert request.params == %{param: "value"}
      assert is_integer(request.id)
    end

    test "creates a request with provided ID" do
      request = JsonRpc.build_jsonrpc_request("test/method", %{param: "value"}, 42)
      
      assert request.id == 42
    end

    test "handles nil params" do
      request = JsonRpc.build_jsonrpc_request("test/method", nil, 1)
      
      assert request.params == nil
    end

    test "raises for invalid method" do
      assert_raise FunctionClauseError, fn ->
        JsonRpc.build_jsonrpc_request(nil, %{}, 1)
      end
    end
  end

  describe "build_jsonrpc_notification/2" do
    test "creates a valid notification" do
      notification = JsonRpc.build_jsonrpc_notification("notification/method", %{data: "test"})
      
      assert %Notification{} = notification
      assert notification.jsonrpc == "2.0"
      assert notification.method == "notification/method"
      assert notification.params == %{data: "test"}
    end

    test "handles nil params" do
      notification = JsonRpc.build_jsonrpc_notification("notification/method")
      
      assert notification.params == nil
    end
  end

  describe "build_jsonrpc_response/2" do
    test "creates a successful response" do
      response = JsonRpc.build_jsonrpc_response(%{result: "success"}, 123)
      
      assert %Response{} = response
      assert response.jsonrpc == "2.0"
      assert response.id == 123
      assert response.result == %{result: "success"}
      assert response.error == nil
    end
  end

  describe "build_jsonrpc_error/3" do
    test "creates an error response" do
      error_response = JsonRpc.build_jsonrpc_error(-32601, "Method not found", 456)
      
      assert %Response{} = error_response
      assert error_response.jsonrpc == "2.0"
      assert error_response.id == 456
      assert error_response.result == nil
      assert %Error{} = error_response.error
      assert error_response.error.code == -32601
      assert error_response.error.message == "Method not found"
      assert error_response.error.data == nil
    end

    test "creates an error response with data" do
      error_response = JsonRpc.build_jsonrpc_error(-32602, "Invalid params", 789, %{details: "test"})
      
      assert error_response.error.data == %{details: "test"}
    end

    test "raises for invalid parameters" do
      assert_raise FunctionClauseError, fn ->
        JsonRpc.build_jsonrpc_error("not_integer", "message", 1)
      end

      assert_raise FunctionClauseError, fn ->
        JsonRpc.build_jsonrpc_error(-32601, 123, 1)
      end
    end
  end

  describe "parse_jsonrpc_message/1" do
    test "parses a valid request" do
      json = ~s({"jsonrpc":"2.0","method":"test/method","params":{"test":true},"id":1})
      
      assert {:ok, %Request{} = request} = JsonRpc.parse_jsonrpc_message(json)
      assert request.jsonrpc == "2.0"
      assert request.method == "test/method"
      assert request.params == %{"test" => true}
      assert request.id == 1
    end

    test "parses a valid notification" do
      json = ~s({"jsonrpc":"2.0","method":"notification/test","params":{"data":"value"}})
      
      assert {:ok, %Notification{} = notification} = JsonRpc.parse_jsonrpc_message(json)
      assert notification.jsonrpc == "2.0"
      assert notification.method == "notification/test"
      assert notification.params == %{"data" => "value"}
    end

    test "parses a valid response" do
      json = ~s({"jsonrpc":"2.0","result":{"success":true},"id":2})
      
      assert {:ok, %Response{} = response} = JsonRpc.parse_jsonrpc_message(json)
      assert response.jsonrpc == "2.0"
      assert response.result == %{"success" => true}
      assert response.id == 2
      assert response.error == nil
    end

    test "parses a valid error response" do
      json = ~s({"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":3})
      
      assert {:ok, %Response{} = response} = JsonRpc.parse_jsonrpc_message(json)
      assert response.jsonrpc == "2.0"
      assert response.result == nil
      assert response.id == 3
      assert %Error{} = response.error
      assert response.error.code == -32601
      assert response.error.message == "Method not found"
    end

    test "parses a valid batch request" do
      json = ~s([
        {"jsonrpc":"2.0","method":"method1","id":1},
        {"jsonrpc":"2.0","method":"method2","params":{},"id":2},
        {"jsonrpc":"2.0","method":"notification"}
      ])
      
      assert {:ok, %Batch{messages: messages}} = JsonRpc.parse_jsonrpc_message(json)
      assert length(messages) == 3
      
      [req1, req2, notif] = messages
      assert %Request{} = req1
      assert %Request{} = req2
      assert %Notification{} = notif
    end

    test "returns error for invalid JSON" do
      json = ~s({"invalid": json})
      
      assert {:error, {:parse_error, _}} = JsonRpc.parse_jsonrpc_message(json)
    end

    test "returns error for invalid JSON-RPC version" do
      json = ~s({"jsonrpc":"1.0","method":"test","id":1})
      
      assert {:error, {:invalid_request, _}} = JsonRpc.parse_jsonrpc_message(json)
    end

    test "returns error for missing method in request" do
      json = ~s({"jsonrpc":"2.0","params":{},"id":1})
      
      assert {:error, {:invalid_request, _}} = JsonRpc.parse_jsonrpc_message(json)
    end

    test "returns error for response with both result and error" do
      json = ~s({"jsonrpc":"2.0","result":"ok","error":{"code":-1,"message":"test"},"id":1})
      
      assert {:error, {:invalid_response, _}} = JsonRpc.parse_jsonrpc_message(json)
    end

    test "returns error for empty batch" do
      json = ~s([])
      
      assert {:error, {:invalid_request, "Batch cannot be empty"}} = JsonRpc.parse_jsonrpc_message(json)
    end
  end

  describe "encode_jsonrpc_message/1" do
    test "encodes a request" do
      request = JsonRpc.build_jsonrpc_request("test/method", %{param: "value"}, 1)
      
      assert {:ok, json} = JsonRpc.encode_jsonrpc_message(request)
      
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["method"] == "test/method"
      assert decoded["params"] == %{"param" => "value"}
      assert decoded["id"] == 1
    end

    test "encodes a notification" do
      notification = JsonRpc.build_jsonrpc_notification("notification/test", %{data: "value"})
      
      assert {:ok, json} = JsonRpc.encode_jsonrpc_message(notification)
      
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["method"] == "notification/test"
      assert decoded["params"] == %{"data" => "value"}
      refute Map.has_key?(decoded, "id")
    end

    test "encodes a response" do
      response = JsonRpc.build_jsonrpc_response(%{result: "success"}, 2)
      
      assert {:ok, json} = JsonRpc.encode_jsonrpc_message(response)
      
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["result"] == %{"result" => "success"}
      assert decoded["id"] == 2
      refute Map.has_key?(decoded, "error")
    end

    test "encodes an error response" do
      error_response = JsonRpc.build_jsonrpc_error(-32601, "Method not found", 3, %{method: "unknown"})
      
      assert {:ok, json} = JsonRpc.encode_jsonrpc_message(error_response)
      
      decoded = Jason.decode!(json)
      assert decoded["jsonrpc"] == "2.0"
      assert decoded["error"]["code"] == -32601
      assert decoded["error"]["message"] == "Method not found"
      assert decoded["error"]["data"] == %{"method" => "unknown"}
      assert decoded["id"] == 3
      refute Map.has_key?(decoded, "result")
    end

    test "encodes a batch" do
      messages = [
        JsonRpc.build_jsonrpc_request("method1", nil, 1),
        JsonRpc.build_jsonrpc_notification("notification")
      ]
      batch = %Batch{messages: messages}
      
      assert {:ok, json} = JsonRpc.encode_jsonrpc_message(batch)
      
      decoded = Jason.decode!(json)
      assert is_list(decoded)
      assert length(decoded) == 2
    end
  end

  describe "validate_jsonrpc_message/1" do
    test "validates a valid request" do
      request = JsonRpc.build_jsonrpc_request("test/method", %{}, 1)
      
      assert {:ok, ^request} = JsonRpc.validate_jsonrpc_message(request)
    end

    test "validates a valid notification" do
      notification = JsonRpc.build_jsonrpc_notification("test/notification")
      
      assert {:ok, ^notification} = JsonRpc.validate_jsonrpc_message(notification)
    end

    test "validates a valid response" do
      response = JsonRpc.build_jsonrpc_response(%{result: "ok"}, 1)
      
      assert {:ok, ^response} = JsonRpc.validate_jsonrpc_message(response)
    end

    test "returns error for invalid request method" do
      invalid_request = %Request{
        jsonrpc: "2.0",
        method: "",
        params: nil,
        id: 1
      }
      
      assert {:error, {:invalid_request, _}} = JsonRpc.validate_jsonrpc_message(invalid_request)
    end

    test "returns error for invalid response" do
      invalid_response = %Response{
        jsonrpc: "2.0",
        id: 1,
        result: "ok",
        error: %Error{code: -1, message: "error"}
      }
      
      assert {:error, {:invalid_response, _}} = JsonRpc.validate_jsonrpc_message(invalid_response)
    end
  end

  describe "correlate_response/2" do
    test "successfully correlates response with pending request" do
      response = JsonRpc.build_jsonrpc_response(%{result: "ok"}, 123)
      pending_requests = %{123 => %{from: self(), method: "test"}}
      
      assert {:ok, {%{from: from, method: "test"}, remaining}} = 
        JsonRpc.correlate_response(response, pending_requests)
      
      assert from == self()
      assert remaining == %{}
    end

    test "returns error for unknown request ID" do
      response = JsonRpc.build_jsonrpc_response(%{result: "ok"}, 999)
      pending_requests = %{123 => %{from: self()}}
      
      assert {:error, {:unknown_request, _}} = 
        JsonRpc.correlate_response(response, pending_requests)
    end

    test "returns error for non-response message" do
      request = JsonRpc.build_jsonrpc_request("test", nil, 1)
      
      assert {:error, {:invalid_response, _}} = 
        JsonRpc.correlate_response(request, %{})
    end
  end

  describe "utility functions" do
    test "generate_id/0 returns unique integers" do
      id1 = JsonRpc.generate_id()
      id2 = JsonRpc.generate_id()
      
      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end

    test "is_request?/1 identifies requests" do
      request = JsonRpc.build_jsonrpc_request("test", nil, 1)
      response = JsonRpc.build_jsonrpc_response(%{}, 1)
      
      assert JsonRpc.is_request?(request) == true
      assert JsonRpc.is_request?(response) == false
    end

    test "is_response?/1 identifies responses" do
      request = JsonRpc.build_jsonrpc_request("test", nil, 1)
      response = JsonRpc.build_jsonrpc_response(%{}, 1)
      
      assert JsonRpc.is_response?(request) == false
      assert JsonRpc.is_response?(response) == true
    end

    test "is_notification?/1 identifies notifications" do
      notification = JsonRpc.build_jsonrpc_notification("test")
      request = JsonRpc.build_jsonrpc_request("test", nil, 1)
      
      assert JsonRpc.is_notification?(notification) == true
      assert JsonRpc.is_notification?(request) == false
    end

    test "get_message_id/1 extracts IDs correctly" do
      request = JsonRpc.build_jsonrpc_request("test", nil, 123)
      response = JsonRpc.build_jsonrpc_response(%{}, 456)
      notification = JsonRpc.build_jsonrpc_notification("test")
      
      assert JsonRpc.get_message_id(request) == 123
      assert JsonRpc.get_message_id(response) == 456
      assert JsonRpc.get_message_id(notification) == nil
    end
  end

  describe "standard error responses" do
    test "parse_error/1 creates proper parse error" do
      error = JsonRpc.parse_error(1)
      
      assert %Response{} = error
      assert error.error.code == -32700
      assert error.error.message == "Parse error"
      assert error.id == 1
    end

    test "method_not_found/2 creates proper method not found error" do
      error = JsonRpc.method_not_found("unknown_method", 2)
      
      assert error.error.code == -32601
      assert error.error.message == "Method not found"
      assert error.error.data == %{method: "unknown_method"}
      assert error.id == 2
    end

    test "MCP-specific errors" do
      tool_error = JsonRpc.tool_not_found("missing_tool", 3)
      assert tool_error.error.code == -32004
      assert tool_error.error.data == %{tool: "missing_tool"}

      resource_error = JsonRpc.resource_not_found("file:///missing", 4)
      assert resource_error.error.code == -32003
      assert resource_error.error.data == %{uri: "file:///missing"}

      timeout_error = JsonRpc.timeout_error(5)
      assert timeout_error.error.code == -32002
      assert timeout_error.error.message == "Request timeout"
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed JSON gracefully" do
      malformed_json = ~s({"jsonrpc":"2.0","method":})
      
      assert {:error, {:parse_error, _}} = JsonRpc.parse_jsonrpc_message(malformed_json)
    end

    test "handles unknown message structure" do
      unknown_json = ~s({"unknown":"structure"})
      
      assert {:error, {:invalid_request, _}} = JsonRpc.parse_jsonrpc_message(unknown_json)
    end

    test "validates params field types" do
      # Valid params types
      request_with_map = JsonRpc.build_jsonrpc_request("test", %{key: "value"}, 1)
      assert {:ok, _} = JsonRpc.validate_jsonrpc_message(request_with_map)

      request_with_list = JsonRpc.build_jsonrpc_request("test", ["value1", "value2"], 2)
      assert {:ok, _} = JsonRpc.validate_jsonrpc_message(request_with_list)

      request_with_nil = JsonRpc.build_jsonrpc_request("test", nil, 3)
      assert {:ok, _} = JsonRpc.validate_jsonrpc_message(request_with_nil)
    end

    test "round-trip encoding and parsing" do
      original_request = JsonRpc.build_jsonrpc_request("test/method", %{"param" => "value"}, 42)
      
      {:ok, json} = JsonRpc.encode_jsonrpc_message(original_request)
      {:ok, parsed_request} = JsonRpc.parse_jsonrpc_message(json)
      
      assert parsed_request.jsonrpc == original_request.jsonrpc
      assert parsed_request.method == original_request.method
      assert parsed_request.params == original_request.params
      assert parsed_request.id == original_request.id
    end
  end
end