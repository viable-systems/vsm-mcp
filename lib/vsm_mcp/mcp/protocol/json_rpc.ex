defmodule VsmMcp.MCP.Protocol.JsonRpc do
  @moduledoc """
  JSON-RPC 2.0 protocol implementation for MCP.
  Handles message encoding, decoding, and validation.
  """

  require Logger

  @json_rpc_version "2.0"

  # Request types
  defstruct [:jsonrpc, :method, :params, :id]

  # Response types
  defmodule Response do
    @enforce_keys [:jsonrpc, :id]
    defstruct [:jsonrpc, :id, :result, :error]
  end

  defmodule Error do
    @enforce_keys [:code, :message]
    defstruct [:code, :message, :data]
  end

  # Standard JSON-RPC error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  @doc """
  Create a JSON-RPC request.
  """
  def request(method, params, id) do
    %__MODULE__{
      jsonrpc: @json_rpc_version,
      method: method,
      params: params,
      id: id
    }
  end

  @doc """
  Create a JSON-RPC notification (request without ID).
  """
  def notification(method, params) do
    %__MODULE__{
      jsonrpc: @json_rpc_version,
      method: method,
      params: params,
      id: nil
    }
  end

  @doc """
  Create a successful JSON-RPC response.
  """
  def success_response(result, id) do
    %Response{
      jsonrpc: @json_rpc_version,
      id: id,
      result: result
    }
  end

  @doc """
  Create an error JSON-RPC response.
  """
  def error_response(code, message, id, data \\ nil) do
    %Response{
      jsonrpc: @json_rpc_version,
      id: id,
      error: %Error{
        code: code,
        message: message,
        data: data
      }
    }
  end

  @doc """
  Parse a JSON-RPC message from JSON string.
  """
  def parse(json_string) do
    with {:ok, data} <- Jason.decode(json_string),
         {:ok, message} <- validate_message(data) do
      {:ok, message}
    else
      {:error, %Jason.DecodeError{} = error} ->
        Logger.error("JSON parse error: #{inspect(error)}")
        {:error, :parse_error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Encode a JSON-RPC message to JSON string.
  """
  def encode(%__MODULE__{} = request) do
    request
    |> Map.from_struct()
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
    |> Jason.encode()
  end

  def encode(%Response{} = response) do
    response
    |> Map.from_struct()
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.update(:error, nil, fn error ->
      if error, do: Map.from_struct(error) |> Map.reject(fn {_k, v} -> is_nil(v) end)
    end)
    |> Jason.encode()
  end

  # Validation helpers
  defp validate_message(%{"jsonrpc" => "2.0"} = data) do
    cond do
      Map.has_key?(data, "method") ->
        validate_request(data)

      Map.has_key?(data, "result") or Map.has_key?(data, "error") ->
        validate_response(data)

      true ->
        {:error, :invalid_message}
    end
  end

  defp validate_message(_), do: {:error, :invalid_jsonrpc_version}

  defp validate_request(%{"method" => method} = data) when is_binary(method) do
    request = %__MODULE__{
      jsonrpc: "2.0",
      method: method,
      params: Map.get(data, "params"),
      id: Map.get(data, "id")
    }

    {:ok, request}
  end

  defp validate_request(_), do: {:error, :invalid_request}

  defp validate_response(%{"id" => id} = data) do
    response = %Response{
      jsonrpc: "2.0",
      id: id
    }

    response =
      case data do
        %{"result" => result} ->
          %{response | result: result}

        %{"error" => %{"code" => code, "message" => message} = error} ->
          error_struct = %Error{
            code: code,
            message: message,
            data: Map.get(error, "data")
          }

          %{response | error: error_struct}

        _ ->
          nil
      end

    if response, do: {:ok, response}, else: {:error, :invalid_response}
  end

  defp validate_response(_), do: {:error, :invalid_response}

  @doc """
  Standard error responses.
  """
  def parse_error(id \\ nil) do
    error_response(@parse_error, "Parse error", id)
  end

  def invalid_request(id \\ nil) do
    error_response(@invalid_request, "Invalid Request", id)
  end

  def method_not_found(method, id) do
    error_response(@method_not_found, "Method not found", id, %{method: method})
  end

  def invalid_params(id) do
    error_response(@invalid_params, "Invalid params", id)
  end

  def internal_error(id, message \\ "Internal error") do
    error_response(@internal_error, message, id)
  end
end