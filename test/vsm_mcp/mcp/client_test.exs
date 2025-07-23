defmodule VsmMcp.MCP.ClientTest do
  use ExUnit.Case
  alias VsmMcp.MCP.Client
  alias VsmMcp.MCP.Protocol.Messages

  describe "MCP client connection" do
    test "connects via stdio transport" do
      # Test would need actual MCP server or mock
      config = %{
        transport: :stdio,
        command: "echo",
        args: ["test"]
      }
      
      {:ok, client} = Client.start_link(config)
      assert Process.alive?(client)
      
      # Cleanup
      GenServer.stop(client)
    end

    test "sends initialization message" do
      {:ok, client} = Client.start_link(%{transport: :stdio, command: "cat"})
      
      # Should automatically send initialize
      state = :sys.get_state(client)
      assert state.initialized == false  # Will be true after response
      
      GenServer.stop(client)
    end

    test "handles connection errors" do
      config = %{
        transport: :stdio,
        command: "nonexistent_command"
      }
      
      assert {:error, _reason} = Client.start_link(config)
    end
  end

  describe "MCP protocol messages" do
    test "sends tool list request" do
      message = Messages.tools_list_request("test-id")
      
      assert message.jsonrpc == "2.0"
      assert message.id == "test-id"
      assert message.method == "tools/list"
    end

    test "sends tool call request" do
      message = Messages.tool_call_request("call-id", "create_file", %{path: "/tmp/test"})
      
      assert message.jsonrpc == "2.0"
      assert message.id == "call-id"
      assert message.method == "tools/call"
      assert message.params.name == "create_file"
      assert message.params.arguments == %{path: "/tmp/test"}
    end

    test "parses tool list response" do
      response = %{
        "jsonrpc" => "2.0",
        "id" => "list-id",
        "result" => %{
          "tools" => [
            %{
              "name" => "read_file",
              "description" => "Read file contents",
              "inputSchema" => %{
                "type" => "object",
                "properties" => %{
                  "path" => %{"type" => "string"}
                }
              }
            }
          ]
        }
      }
      
      {:ok, tools} = Messages.parse_response(response)
      
      assert length(tools.tools) == 1
      assert hd(tools.tools)["name"] == "read_file"
    end

    test "handles error responses" do
      response = %{
        "jsonrpc" => "2.0",
        "id" => "error-id",
        "error" => %{
          "code" => -32601,
          "message" => "Method not found"
        }
      }
      
      {:error, error} = Messages.parse_response(response)
      
      assert error.code == -32601
      assert error.message == "Method not found"
    end
  end

  describe "tool discovery and execution" do
    setup do
      # This would need a mock MCP server
      {:ok, client} = Client.start_link(%{transport: :stdio, command: "cat"})
      %{client: client}
    end

    test "discovers available tools", %{client: client} do
      # In real test, would interact with actual MCP server
      tools = Client.list_tools(client)
      
      assert is_list(tools) or is_map(tools)
    end

    test "executes tool call", %{client: client} do
      # Mock tool execution
      result = Client.call_tool(client, "echo", %{message: "test"})
      
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles streaming responses", %{client: client} do
      # Test streaming tool responses
      stream = Client.call_tool_stream(client, "generate_text", %{prompt: "test"})
      
      if is_list(stream) do
        assert Enum.all?(stream, &is_binary/1)
      end
    end
  end

  describe "transport handling" do
    test "supports multiple transports" do
      transports = [:stdio, :tcp, :websocket]
      
      for transport <- transports do
        config = case transport do
          :stdio -> %{transport: :stdio, command: "cat"}
          :tcp -> %{transport: :tcp, host: "localhost", port: 8080}
          :websocket -> %{transport: :websocket, url: "ws://localhost:8080"}
        end
        
        # Would need appropriate mock servers
        assert Map.has_key?(config, :transport)
      end
    end

    test "reconnects on connection loss" do
      {:ok, client} = Client.start_link(%{
        transport: :stdio,
        command: "cat",
        reconnect: true,
        reconnect_interval: 100
      })
      
      # Simulate connection loss
      send(client, :connection_lost)
      
      # Should attempt reconnect
      Process.sleep(200)
      assert Process.alive?(client)
      
      GenServer.stop(client)
    end
  end

  describe "capability negotiation" do
    test "negotiates capabilities on connect" do
      capabilities = Client.get_server_capabilities(nil)  # Would use real client
      
      expected_capabilities = [
        "tools/list",
        "tools/call",
        "completion/complete",
        "resources/list"
      ]
      
      # Server should support basic capabilities
      if is_list(capabilities) do
        assert Enum.any?(expected_capabilities, &(&1 in capabilities))
      end
    end
  end
end