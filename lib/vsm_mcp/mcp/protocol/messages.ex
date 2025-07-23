defmodule VsmMcp.MCP.Protocol.Messages do
  @moduledoc """
  MCP protocol message types and builders.
  Implements the Model Context Protocol specification.
  """

  # Initialize messages
  def initialize_request(protocol_version, capabilities, client_info) do
    %{
      method: "initialize",
      params: %{
        protocolVersion: protocol_version,
        capabilities: capabilities,
        clientInfo: client_info
      }
    }
  end

  def initialize_response(protocol_version, capabilities, server_info) do
    %{
      protocolVersion: protocol_version,
      capabilities: capabilities,
      serverInfo: server_info
    }
  end

  # Capability discovery
  def list_tools_request, do: %{method: "tools/list", params: %{}}
  def list_resources_request, do: %{method: "resources/list", params: %{}}
  def list_prompts_request, do: %{method: "prompts/list", params: %{}}

  # Tool invocation
  def call_tool_request(name, arguments) do
    %{
      method: "tools/call",
      params: %{
        name: name,
        arguments: arguments
      }
    }
  end

  # Resource access
  def read_resource_request(uri) do
    %{
      method: "resources/read",
      params: %{
        uri: uri
      }
    }
  end

  def subscribe_resource_request(uri) do
    %{
      method: "resources/subscribe",
      params: %{
        uri: uri
      }
    }
  end

  def unsubscribe_resource_request(uri) do
    %{
      method: "resources/unsubscribe",
      params: %{
        uri: uri
      }
    }
  end

  # Resource notifications
  def resource_updated_notification(uri) do
    %{
      method: "notifications/resources/updated",
      params: %{
        uri: uri
      }
    }
  end

  def resource_list_changed_notification do
    %{
      method: "notifications/resources/list_changed",
      params: %{}
    }
  end

  # Prompt handling
  def get_prompt_request(name, arguments \\ %{}) do
    %{
      method: "prompts/get",
      params: %{
        name: name,
        arguments: arguments
      }
    }
  end

  # Logging
  def log_message_notification(level, logger, data) do
    %{
      method: "notifications/message",
      params: %{
        level: level,
        logger: logger,
        data: data
      }
    }
  end

  # Progress notifications
  def progress_notification(progress_token, progress, total) do
    %{
      method: "notifications/progress",
      params: %{
        progressToken: progress_token,
        progress: progress,
        total: total
      }
    }
  end

  # Completion
  def completion_request(ref, argument, values) do
    %{
      method: "completion/complete",
      params: %{
        ref: ref,
        argument: %{
          name: argument.name,
          value: argument.value
        },
        values: values
      }
    }
  end

  # Ping/Pong for keep-alive
  def ping_request, do: %{method: "ping", params: %{}}
  def ping_response, do: %{}

  # Shutdown
  def shutdown_notification do
    %{
      method: "notifications/cancelled",
      params: %{
        reason: "Client requested cancellation"
      }
    }
  end

  # Error codes specific to MCP
  @mcp_error_codes %{
    connection_error: -32001,
    timeout_error: -32002,
    resource_not_found: -32003,
    tool_not_found: -32004,
    invalid_capabilities: -32005
  }

  def error_code(type), do: Map.get(@mcp_error_codes, type, -32603)
end