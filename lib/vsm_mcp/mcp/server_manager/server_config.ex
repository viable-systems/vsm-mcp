defmodule VsmMcp.MCP.ServerManager.ServerConfig do
  @moduledoc """
  Configuration validation and management for MCP servers.
  """
  
  @type t :: %__MODULE__{
    id: String.t() | nil,
    type: :external | :internal | :custom,
    command: String.t() | nil,
    args: list(String.t()),
    env: map(),
    working_dir: String.t() | nil,
    server_opts: keyword(),
    pool_size: pos_integer(),
    max_overflow: pos_integer(),
    restart_policy: :permanent | :transient | :temporary,
    health_check: map(),
    timeout_ms: pos_integer(),
    start_fn: function() | nil,
    metadata: map()
  }
  
  defstruct [
    :id,
    :type,
    :command,
    :args,
    :env,
    :working_dir,
    :server_opts,
    :pool_size,
    :max_overflow,
    :restart_policy,
    :health_check,
    :timeout_ms,
    :start_fn,
    :metadata
  ]
  
  @default_pool_size 10
  @default_max_overflow 5
  @default_timeout_ms 30_000
  
  @doc """
  Validate and normalize server configuration.
  """
  def validate(%__MODULE__{} = config) do
    # Already a struct, just validate it
    with :ok <- validate_type(config),
         :ok <- validate_required_fields(config),
         :ok <- validate_command(config),
         :ok <- validate_health_check(config) do
      {:ok, config}
    end
  end
  
  def validate(config) when is_map(config) do
    with :ok <- validate_type(config),
         :ok <- validate_required_fields(config),
         :ok <- validate_command(config),
         :ok <- validate_health_check(config) do
      
      normalized = %__MODULE__{
        id: config[:id],
        type: String.to_atom(to_string(config[:type] || :external)),
        command: config[:command],
        args: config[:args] || [],
        env: config[:env] || %{},
        working_dir: config[:working_dir],
        server_opts: config[:server_opts] || [],
        pool_size: config[:pool_size] || @default_pool_size,
        max_overflow: config[:max_overflow] || @default_max_overflow,
        restart_policy: String.to_atom(to_string(config[:restart_policy] || :permanent)),
        health_check: normalize_health_check(config[:health_check]),
        timeout_ms: config[:timeout_ms] || @default_timeout_ms,
        start_fn: config[:start_fn],
        metadata: config[:metadata] || %{}
      }
      
      {:ok, normalized}
    end
  end
  
  def validate(_), do: {:error, :invalid_config_format}
  
  @doc """
  Create configuration for common MCP server types.
  """
  def create_preset(type, opts \\ []) do
    case type do
      :stdio ->
        %{
          type: :external,
          command: opts[:command] || raise("Command required for stdio server"),
          args: opts[:args] || [],
          env: opts[:env] || %{},
          health_check: %{
            type: :stdio,
            interval_ms: 30_000,
            timeout_ms: 5_000,
            init_message: %{
              jsonrpc: "2.0",
              method: "initialize",
              params: %{
                protocolVersion: "0.1.0",
                capabilities: %{}
              }
            }
          }
        }
        
      :tcp ->
        %{
          type: :internal,
          server_opts: [
            transport: :tcp,
            port: opts[:port] || 3333,
            auto_start: true
          ],
          health_check: %{
            type: :tcp,
            interval_ms: 30_000,
            timeout_ms: 5_000,
            port: opts[:port] || 3333
          }
        }
        
      :websocket ->
        %{
          type: :internal,
          server_opts: [
            transport: :websocket,
            port: opts[:port] || 8080,
            path: opts[:path] || "/mcp",
            auto_start: true
          ],
          health_check: %{
            type: :websocket,
            interval_ms: 30_000,
            timeout_ms: 5_000,
            url: "ws://localhost:#{opts[:port] || 8080}#{opts[:path] || "/mcp"}"
          }
        }
        
      :custom ->
        Map.merge(%{
          type: :custom,
          start_fn: opts[:start_fn] || raise("start_fn required for custom server"),
          health_check: %{
            type: :custom,
            check_fn: opts[:health_check_fn] || fn _ -> {:ok, :healthy} end,
            interval_ms: 30_000,
            timeout_ms: 5_000
          }
        }, opts)
    end
    |> Map.merge(Map.take(opts, [:id, :restart_policy, :pool_size, :max_overflow, :metadata]))
  end
  
  # Private functions
  
  defp validate_type(%__MODULE__{type: type}) when type in [:external, :internal, :custom], do: :ok
  defp validate_type(%__MODULE__{type: type}) when is_binary(type) do
    if type in ["external", "internal", "custom"], do: :ok, else: {:error, :invalid_type}
  end
  defp validate_type(%{type: type}) when type in [:external, :internal, :custom], do: :ok
  defp validate_type(%{type: type}) when is_binary(type) do
    if type in ["external", "internal", "custom"], do: :ok, else: {:error, :invalid_type}
  end
  defp validate_type(_), do: :ok  # Default to external
  
  defp validate_required_fields(%__MODULE__{} = config) do
    cond do
      config.type == :external and is_nil(config.command) ->
        {:error, :command_required_for_external}
        
      config.type == :custom and is_nil(config.start_fn) ->
        {:error, :start_fn_required_for_custom}
        
      true ->
        :ok
    end
  end
  
  defp validate_required_fields(config) when is_map(config) do
    cond do
      Map.get(config, :type) == :external and is_nil(Map.get(config, :command)) ->
        {:error, :command_required_for_external}
        
      Map.get(config, :type) == :custom and is_nil(Map.get(config, :start_fn)) ->
        {:error, :start_fn_required_for_custom}
        
      true ->
        :ok
    end
  end
  
  defp validate_command(%__MODULE__{type: :external, command: command}) when is_binary(command) do
    # Check if command exists and is executable
    case System.find_executable(command) do
      nil ->
        # Check if it's a relative path or complex command
        if String.contains?(command, "/") or String.contains?(command, " ") do
          :ok  # Assume it's valid for now
        else
          {:error, {:command_not_found, command}}
        end
        
      _path ->
        :ok
    end
  end
  
  defp validate_command(%{type: :external, command: command}) when is_binary(command) do
    # Check if command exists and is executable
    case System.find_executable(command) do
      nil ->
        # Check if it's a relative path or complex command
        if String.contains?(command, "/") or String.contains?(command, " ") do
          :ok  # Assume it's valid for now
        else
          {:error, {:command_not_found, command}}
        end
        
      _path ->
        :ok
    end
  end
  defp validate_command(_), do: :ok
  
  defp validate_health_check(%__MODULE__{health_check: config}) when is_map(config) do
    required_fields = case config[:type] do
      :stdio -> [:init_message]
      :tcp -> [:port]
      :websocket -> [:url]
      :custom -> [:check_fn]
      _ -> []
    end
    
    missing = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_health_check_fields, missing}}
    end
  end
  
  defp validate_health_check(%{health_check: config}) when is_map(config) do
    required_fields = case config[:type] do
      :stdio -> [:init_message]
      :tcp -> [:port]
      :websocket -> [:url]
      :custom -> [:check_fn]
      _ -> []
    end
    
    missing = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_health_check_fields, missing}}
    end
  end
  defp validate_health_check(_), do: :ok
  
  defp normalize_health_check(nil) do
    %{
      type: :basic,
      interval_ms: 30_000,
      timeout_ms: 5_000,
      enabled: true
    }
  end
  
  defp normalize_health_check(config) when is_map(config) do
    Map.merge(%{
      interval_ms: 30_000,
      timeout_ms: 5_000,
      enabled: true
    }, config)
  end
end