defmodule VsmMcp.MCP.ProtocolTest do
  use ExUnit.Case
  alias VsmMcp.MCP.Protocol.{JsonRpc, Messages}

  describe "JsonRpc" do
    test "creates valid request" do
      request = JsonRpc.request("test_method", %{param: "value"}, 1)
      
      assert request.jsonrpc == "2.0"
      assert request.method == "test_method"
      assert request.params == %{param: "value"}
      assert request.id == 1
    end

    test "creates valid notification" do
      notification = JsonRpc.notification("test_notification", %{data: "test"})
      
      assert notification.jsonrpc == "2.0"
      assert notification.method == "test_notification"
      assert notification.params == %{data: "test"}
      assert notification.id == nil
    end

    test "creates success response" do
      response = JsonRpc.success_response(%{result: "success"}, 42)
      
      assert response.jsonrpc == "2.0"
      assert response.id == 42
      assert response.result == %{result: "success"}
      assert response.error == nil
    end

    test "creates error response" do
      response = JsonRpc.error_response(-32600, "Invalid Request", 1, %{detail: "test"})
      
      assert response.jsonrpc == "2.0"
      assert response.id == 1
      assert response.result == nil
      assert response.error.code == -32600
      assert response.error.message == "Invalid Request"
      assert response.error.data == %{detail: "test"}
    end

    test "encodes request to JSON" do
      request = JsonRpc.request("test", %{}, 1)
      {:ok, json} = JsonRpc.encode(request)
      
      assert json =~ ~s("jsonrpc":"2.0")
      assert json =~ ~s("method":"test")
      assert json =~ ~s("id":1)
    end

    test "parses valid JSON-RPC request" do
      json = ~s({"jsonrpc":"2.0","method":"test","params":{"key":"value"},"id":1})
      
      {:ok, request} = JsonRpc.parse(json)
      
      assert request.jsonrpc == "2.0"
      assert request.method == "test"
      assert request.params == %{"key" => "value"}
      assert request.id == 1
    end

    test "parses valid JSON-RPC response" do
      json = ~s({"jsonrpc":"2.0","result":{"data":"test"},"id":1})
      
      {:ok, response} = JsonRpc.parse(json)
      
      assert %JsonRpc.Response{} = response
      assert response.jsonrpc == "2.0"
      assert response.result == %{"data" => "test"}
      assert response.id == 1
    end

    test "handles parse errors" do
      assert {:error, :parse_error} = JsonRpc.parse("invalid json")
    end
  end

  describe "Messages" do
    test "creates initialize request" do
      msg = Messages.initialize_request("2024-11-05", %{tools: %{}}, %{name: "test"})
      
      assert msg.method == "initialize"
      assert msg.params.protocolVersion == "2024-11-05"
      assert msg.params.capabilities == %{tools: %{}}
      assert msg.params.clientInfo == %{name: "test"}
    end

    test "creates tool call request" do
      msg = Messages.call_tool_request("my_tool", %{input: "test"})
      
      assert msg.method == "tools/call"
      assert msg.params.name == "my_tool"
      assert msg.params.arguments == %{input: "test"}
    end

    test "creates resource read request" do
      msg = Messages.read_resource_request("file:///test.txt")
      
      assert msg.method == "resources/read"
      assert msg.params.uri == "file:///test.txt"
    end

    test "creates prompt get request" do
      msg = Messages.get_prompt_request("test_prompt", %{lang: "en"})
      
      assert msg.method == "prompts/get"
      assert msg.params.name == "test_prompt"
      assert msg.params.arguments == %{lang: "en"}
    end

    test "creates progress notification" do
      msg = Messages.progress_notification("token123", 50, 100)
      
      assert msg.method == "notifications/progress"
      assert msg.params.progressToken == "token123"
      assert msg.params.progress == 50
      assert msg.params.total == 100
    end
  end
end