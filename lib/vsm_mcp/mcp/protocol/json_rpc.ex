defmodule VsmMcp.MCP.Protocol.JsonRpc do
  @moduledoc """
  Bulletproof JSON-RPC 2.0 protocol implementation for MCP.
  
  Provides comprehensive message handling including:
  - Request/response correlation with ID management
  - Proper JSON-RPC 2.0 specification compliance
  - Batch request processing
  - Enhanced error handling and validation
  - Notification support
  - Message correlation and timeout handling
  """

  require Logger
  alias __MODULE__.{Request, Response, Notification, Error, Batch}

  @json_rpc_version "2.0"
  @default_timeout 30_000

  # Message types
  defmodule Request do
    @enforce_keys [:jsonrpc, :method, :id]
    defstruct [:jsonrpc, :method, :params, :id]
  end

  defmodule Response do
    @enforce_keys [:jsonrpc, :id]
    defstruct [:jsonrpc, :id, :result, :error]
  end

  defmodule Notification do
    @enforce_keys [:jsonrpc, :method]
    defstruct [:jsonrpc, :method, :params]
  end

  defmodule Error do
    @enforce_keys [:code, :message]
    defstruct [:code, :message, :data]
  end

  defmodule Batch do
    @enforce_keys [:messages]
    defstruct [:messages]
  end

  # ID generator state
  defmodule IdGenerator do
    use GenServer
    
    def start_link(_) do
      GenServer.start_link(__MODULE__, 1, name: __MODULE__)
    end
    
    def next_id do
      GenServer.call(__MODULE__, :next_id)
    end
    
    def init(initial_id) do
      {:ok, initial_id}
    end
    
    def handle_call(:next_id, _from, id) do
      {:reply, id, id + 1}
    end
  end

  # Standard JSON-RPC error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603
  
  # MCP-specific error codes
  @connection_error -32001
  @timeout_error -32002
  @resource_not_found -32003
  @tool_not_found -32004
  @invalid_capabilities -32005

  @doc """
  Builds a proper JSON-RPC 2.0 request message with auto-generated ID.
  
  ## Parameters
  - method: The method to call (string)
  - params: Parameters for the method (map, list, or nil)
  - id: Optional ID (if nil, auto-generates one)
  
  ## Examples
      iex> build_jsonrpc_request("tools/list", %{}, nil)
      %Request{jsonrpc: "2.0", method: "tools/list", params: %{}, id: 1}
  """
  def build_jsonrpc_request(method, params \\ nil, id \\ nil) when is_binary(method) do
    request_id = id || generate_id()
    
    %Request{
      jsonrpc: @json_rpc_version,
      method: method,
      params: normalize_params(params),
      id: request_id
    }
  end

  @doc """
  Creates a JSON-RPC notification (no response expected).
  
  ## Parameters
  - method: The notification method (string)
  - params: Parameters for the notification (map, list, or nil)
  
  ## Examples
      iex> build_jsonrpc_notification("progress", %{value: 50})
      %Notification{jsonrpc: "2.0", method: "progress", params: %{value: 50}}
  """
  def build_jsonrpc_notification(method, params \\ nil) when is_binary(method) do
    %Notification{
      jsonrpc: @json_rpc_version,
      method: method,
      params: normalize_params(params)
    }
  end

  @doc """
  Builds a successful JSON-RPC 2.0 response.
  
  ## Parameters
  - result: The result data (any JSON-serializable value)
  - id: The request ID to correlate with
  
  ## Examples
      iex> build_jsonrpc_response(%{tools: []}, 1)
      %Response{jsonrpc: "2.0", id: 1, result: %{tools: []}}
  """
  def build_jsonrpc_response(result, id) do
    %Response{
      jsonrpc: @json_rpc_version,
      id: id,
      result: result,
      error: nil
    }
  end

  @doc """
  Builds a JSON-RPC 2.0 error response.
  
  ## Parameters
  - code: Error code (integer)
  - message: Error message (string)
  - id: The request ID to correlate with
  - data: Optional additional error data
  
  ## Examples
      iex> build_jsonrpc_error(-32601, "Method not found", 1, %{method: "unknown"})
      %Response{jsonrpc: "2.0", id: 1, error: %Error{code: -32601, message: "Method not found", data: %{method: "unknown"}}}
  """
  def build_jsonrpc_error(code, message, id, data \\ nil) 
      when is_integer(code) and is_binary(message) do
    %Response{
      jsonrpc: @json_rpc_version,
      id: id,
      result: nil,
      error: %Error{
        code: code,
        message: message,
        data: data
      }
    }
  end

  @doc """
  Parses incoming JSON-RPC message with comprehensive validation.
  
  Handles single messages, batch requests, and various error conditions.
  
  ## Parameters
  - json_string: Raw JSON string to parse
  
  ## Returns
  - `{:ok, message}` - Successfully parsed message
  - `{:error, reason}` - Parse or validation error
  
  ## Examples
      iex> parse_jsonrpc_message(~s({"jsonrpc":"2.0","method":"ping","id":1}))
      {:ok, %Request{jsonrpc: "2.0", method: "ping", id: 1}}
  """
  def parse_jsonrpc_message(json_string) when is_binary(json_string) do
    with {:json_decode, {:ok, data}} <- {:json_decode, Jason.decode(json_string)},
         {:validate, {:ok, message}} <- {:validate, validate_and_parse_message(data)} do
      {:ok, message}
    else
      {:json_decode, {:error, %Jason.DecodeError{} = error}} ->
        Logger.error("JSON parse error: #{inspect(error)}")
        {:error, {:parse_error, "Invalid JSON: #{error.data}"}}

      {:validate, {:error, reason}} ->
        Logger.error("Message validation error: #{inspect(reason)}")
        {:error, reason}

      {:error, reason} ->
        Logger.error("Unexpected error parsing message: #{inspect(reason)}")
        {:error, {:internal_error, inspect(reason)}}
    end
  end

  @doc """
  Encodes a JSON-RPC message to JSON string with proper formatting.
  
  Handles all message types: requests, responses, notifications, and batches.
  
  ## Parameters
  - message: Any JSON-RPC message struct
  
  ## Returns
  - `{:ok, json_string}` - Successfully encoded
  - `{:error, reason}` - Encoding error
  """
  def encode_jsonrpc_message(%Request{} = request) do
    request
    |> struct_to_map()
    |> Jason.encode()
    |> handle_encode_result()
  end

  def encode_jsonrpc_message(%Response{} = response) do
    response
    |> struct_to_map()
    |> normalize_response_fields()
    |> Jason.encode()
    |> handle_encode_result()
  end

  def encode_jsonrpc_message(%Notification{} = notification) do
    notification
    |> struct_to_map()
    |> Jason.encode()
    |> handle_encode_result()
  end

  def encode_jsonrpc_message(%Batch{messages: messages}) do
    messages
    |> Enum.map(&struct_to_map/1)
    |> Enum.map(&normalize_message_fields/1)
    |> Jason.encode()
    |> handle_encode_result()
  end

  # Legacy support for old function names
  def encode(message), do: encode_jsonrpc_message(message)

  @doc """
  Validates a JSON-RPC message structure according to the specification.
  
  ## Parameters
  - message: Parsed JSON data (map or list)
  
  ## Returns
  - `{:ok, message}` - Valid message
  - `{:error, reason}` - Validation error
  """
  def validate_jsonrpc_message(%Request{} = request) do
    with :ok <- validate_jsonrpc_version(request.jsonrpc),
         :ok <- validate_method(request.method),
         :ok <- validate_id(request.id),
         :ok <- validate_params(request.params) do
      {:ok, request}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_jsonrpc_message(%Response{} = response) do
    with :ok <- validate_jsonrpc_version(response.jsonrpc),
         :ok <- validate_response_id(response.id),
         :ok <- validate_response_content(response) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_jsonrpc_message(%Notification{} = notification) do
    with :ok <- validate_jsonrpc_version(notification.jsonrpc),
         :ok <- validate_method(notification.method),
         :ok <- validate_params(notification.params) do
      {:ok, notification}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_jsonrpc_message(%Batch{messages: messages}) when is_list(messages) do
    if length(messages) == 0 do
      {:error, {:invalid_request, "Batch cannot be empty"}}
    else
      case Enum.find(messages, fn msg -> 
        case validate_jsonrpc_message(msg) do
          {:ok, _} -> false
          {:error, _} -> true
        end
      end) do
        nil -> {:ok, %Batch{messages: messages}}
        _invalid -> {:error, {:invalid_request, "Invalid message in batch"}}
      end
    end
  end

  def validate_jsonrpc_message(_), do: {:error, {:invalid_request, "Unknown message type"}}

  # Message validation and parsing
  defp validate_and_parse_message(data) when is_list(data) do
    # Batch request
    if length(data) == 0 do
      {:error, {:invalid_request, "Batch cannot be empty"}}
    else
      case parse_batch_messages(data) do
        {:ok, messages} -> {:ok, %Batch{messages: messages}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_and_parse_message(%{"jsonrpc" => "2.0"} = data) do
    cond do
      Map.has_key?(data, "method") ->
        parse_request_or_notification(data)

      Map.has_key?(data, "result") or Map.has_key?(data, "error") ->
        parse_response(data)

      true ->
        {:error, {:invalid_request, "Missing required fields"}}
    end
  end

  defp validate_and_parse_message(%{"jsonrpc" => version}) do
    {:error, {:invalid_request, "Invalid JSON-RPC version: #{version}"}}
  end

  defp validate_and_parse_message(_) do
    {:error, {:invalid_request, "Missing jsonrpc field"}}
  end

  @doc """
  Correlates a response with its original request using ID matching.
  
  ## Parameters
  - response: The response message
  - pending_requests: Map of pending request IDs
  
  ## Returns
  - `{:ok, {request_info, remaining_requests}}` - Successfully correlated
  - `{:error, reason}` - Correlation failed
  """
  def correlate_response(%Response{id: id} = response, pending_requests) when is_map(pending_requests) do
    case Map.pop(pending_requests, id) do
      {nil, _} ->
        Logger.warn("Received response for unknown request ID: #{inspect(id)}")
        {:error, {:unknown_request, "No pending request found for ID: #{inspect(id)}"}}

      {request_info, remaining} ->
        {:ok, {request_info, remaining}}
    end
  end

  def correlate_response(response, _) do
    {:error, {:invalid_response, "Cannot correlate non-response message: #{inspect(response)}"}}
  end

  # Batch message parsing
  defp parse_batch_messages(messages) do
    parsed_messages = 
      Enum.map(messages, fn msg ->
        case validate_and_parse_message(msg) do
          {:ok, parsed} -> parsed
          {:error, reason} -> {:error, reason}
        end
      end)

    errors = Enum.filter(parsed_messages, &match?({:error, _}, &1))
    
    if length(errors) > 0 do
      {:error, {:invalid_request, "Invalid messages in batch: #{inspect(errors)}"}}
    else
      {:ok, parsed_messages}
    end
  end

  # Request/notification parsing
  defp parse_request_or_notification(%{"method" => method} = data) when is_binary(method) do
    params = Map.get(data, "params")
    id = Map.get(data, "id")

    # If ID is present, it's a request; otherwise, it's a notification
    if Map.has_key?(data, "id") do
      request = %Request{
        jsonrpc: @json_rpc_version,
        method: method,
        params: params,
        id: id
      }
      {:ok, request}
    else
      notification = %Notification{
        jsonrpc: @json_rpc_version,
        method: method,
        params: params
      }
      {:ok, notification}
    end
  end

  defp parse_request_or_notification(_) do
    {:error, {:invalid_request, "Invalid method field"}}
  end

  # Response parsing  
  defp parse_response(%{"id" => id} = data) do
    cond do
      Map.has_key?(data, "result") and Map.has_key?(data, "error") ->
        {:error, {:invalid_response, "Response cannot have both result and error"}}

      Map.has_key?(data, "result") ->
        response = %Response{
          jsonrpc: @json_rpc_version,
          id: id,
          result: data["result"],
          error: nil
        }
        {:ok, response}

      Map.has_key?(data, "error") ->
        case parse_error_data(data["error"]) do
          {:ok, error} ->
            response = %Response{
              jsonrpc: @json_rpc_version,
              id: id,
              result: nil,
              error: error
            }
            {:ok, response}
          {:error, reason} -> {:error, reason}
        end

      true ->
        {:error, {:invalid_response, "Response must have either result or error"}}
    end
  end

  defp parse_response(_) do
    {:error, {:invalid_response, "Response must have id field"}}
  end

  # Error parsing
  defp parse_error_data(%{"code" => code, "message" => message} = error_data) 
       when is_integer(code) and is_binary(message) do
    error = %Error{
      code: code,
      message: message,
      data: Map.get(error_data, "data")
    }
    {:ok, error}
  end

  defp parse_error_data(_) do
    {:error, {:invalid_response, "Error must have code and message fields"}}
  end

  # Standard error response builders
  @doc "Creates a parse error response"
  def parse_error(id \\ nil) do
    build_jsonrpc_error(@parse_error, "Parse error", id)
  end

  @doc "Creates an invalid request error response"
  def invalid_request(id \\ nil) do
    build_jsonrpc_error(@invalid_request, "Invalid Request", id)
  end

  @doc "Creates a method not found error response"
  def method_not_found(method, id) do
    build_jsonrpc_error(@method_not_found, "Method not found", id, %{method: method})
  end

  @doc "Creates an invalid params error response"
  def invalid_params(id) do
    build_jsonrpc_error(@invalid_params, "Invalid params", id)
  end

  @doc "Creates an internal error response"
  def internal_error(id, message \\ "Internal error") do
    build_jsonrpc_error(@internal_error, message, id)
  end

  # MCP-specific error responses
  @doc "Creates a connection error response"
  def connection_error(id, message \\ "Connection error") do
    build_jsonrpc_error(@connection_error, message, id)
  end

  @doc "Creates a timeout error response"
  def timeout_error(id, message \\ "Request timeout") do
    build_jsonrpc_error(@timeout_error, message, id)
  end

  @doc "Creates a resource not found error response"
  def resource_not_found(uri, id) do
    build_jsonrpc_error(@resource_not_found, "Resource not found", id, %{uri: uri})
  end

  @doc "Creates a tool not found error response"
  def tool_not_found(tool_name, id) do
    build_jsonrpc_error(@tool_not_found, "Tool not found", id, %{tool: tool_name})
  end

  @doc "Creates an invalid capabilities error response"
  def invalid_capabilities(id, message \\ "Invalid capabilities") do
    build_jsonrpc_error(@invalid_capabilities, message, id)
  end

  # Utility functions
  
  @doc "Generates a unique ID for requests"
  def generate_id do
    case Process.whereis(IdGenerator) do
      nil -> :rand.uniform(1_000_000)
      _pid -> IdGenerator.next_id()
    end
  end

  @doc "Checks if a message is a request"
  def is_request?(%Request{}), do: true
  def is_request?(_), do: false

  @doc "Checks if a message is a response"
  def is_response?(%Response{}), do: true
  def is_response?(_), do: false

  @doc "Checks if a message is a notification"
  def is_notification?(%Notification{}), do: true
  def is_notification?(_), do: false

  @doc "Checks if a message is a batch"
  def is_batch?(%Batch{}), do: true
  def is_batch?(_), do: false

  @doc "Gets the ID from a message (nil for notifications)"
  def get_message_id(%Request{id: id}), do: id
  def get_message_id(%Response{id: id}), do: id
  def get_message_id(%Notification{}), do: nil
  def get_message_id(_), do: nil

  # Private helper functions

  defp normalize_params(nil), do: nil
  defp normalize_params(params) when is_map(params) or is_list(params), do: params
  defp normalize_params(params), do: params

  defp struct_to_map(struct) do
    struct
    |> Map.from_struct()
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp normalize_response_fields(response_map) do
    case Map.get(response_map, :error) do
      %Error{} = error ->
        error_map = 
          error
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
        Map.put(response_map, :error, error_map)
      _ ->
        response_map
    end
  end

  defp normalize_message_fields(message_map) do
    case Map.get(message_map, :error) do
      %Error{} = error ->
        error_map = 
          error
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
        Map.put(message_map, :error, error_map)
      _ ->
        message_map
    end
  end

  defp handle_encode_result({:ok, json}), do: {:ok, json}
  defp handle_encode_result({:error, reason}) do
    Logger.error("JSON encoding error: #{inspect(reason)}")
    {:error, {:encoding_error, inspect(reason)}}
  end

  # Validation helpers
  defp validate_jsonrpc_version(@json_rpc_version), do: :ok
  defp validate_jsonrpc_version(version) do
    {:error, {:invalid_request, "Invalid JSON-RPC version: #{version}"}}
  end

  defp validate_method(method) when is_binary(method) do
    if String.trim(method) != "" do
      :ok
    else
      {:error, {:invalid_request, "Method cannot be empty"}}
    end
  end
  defp validate_method(_), do: {:error, {:invalid_request, "Method must be a string"}}

  defp validate_id(id) when is_integer(id) or is_binary(id) or is_nil(id), do: :ok
  defp validate_id(_), do: {:error, {:invalid_request, "ID must be string, number, or null"}}

  defp validate_response_id(id) when is_integer(id) or is_binary(id), do: :ok
  defp validate_response_id(_), do: {:error, {:invalid_response, "Response ID must be string or number"}}

  defp validate_params(nil), do: :ok
  defp validate_params(params) when is_map(params) or is_list(params), do: :ok
  defp validate_params(_), do: {:error, {:invalid_params, "Params must be object, array, or null"}}

  defp validate_response_content(%Response{result: result, error: nil}) when not is_nil(result), do: :ok
  defp validate_response_content(%Response{result: nil, error: %Error{}}), do: :ok
  defp validate_response_content(_) do
    {:error, {:invalid_response, "Response must have either result or error, but not both"}}
  end
end