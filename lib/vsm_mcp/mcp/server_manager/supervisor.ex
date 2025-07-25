defmodule VsmMcp.MCP.ServerManager.Supervisor do
  @moduledoc """
  Supervisor for the MCP ServerManager and its components.
  """
  
  use Supervisor
  
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    children = [
      # Main server manager
      {VsmMcp.MCP.ServerManager, opts}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end