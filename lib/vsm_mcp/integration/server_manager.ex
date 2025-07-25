defmodule VsmMcp.Integration.ServerManager do
  @moduledoc """
  Manages MCP server registrations for the integration layer.
  """
  use GenServer
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def register_server(id, client) do
    GenServer.call(__MODULE__, {:register_server, id, client})
  end
  
  def list_servers do
    GenServer.call(__MODULE__, :list_servers)
  end
  
  def get_server(id) do
    GenServer.call(__MODULE__, {:get_server, id})
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      servers: %{},
      registry_updated_at: DateTime.utc_now()
    }
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_server, id, client}, _from, state) do
    new_servers = Map.put(state.servers, id, %{
      id: id,
      client: client,
      registered_at: DateTime.utc_now()
    })
    
    new_state = %{state | servers: new_servers, registry_updated_at: DateTime.utc_now()}
    Logger.info("Registered MCP server: #{id}")
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:list_servers, _from, state) do
    servers = Map.values(state.servers)
    {:reply, servers, state}
  end
  
  @impl true
  def handle_call({:get_server, id}, _from, state) do
    server = Map.get(state.servers, id)
    {:reply, server, state}
  end
end