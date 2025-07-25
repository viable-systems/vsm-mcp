defmodule VsmMcp.LLM.HTTPWorker do
  @moduledoc """
  HTTP worker for connection pooling.
  
  Manages persistent HTTP connections for LLM API requests.
  """
  
  use GenServer
  require Logger
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end
  
  @impl true
  def init(_) do
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:request, method, url, headers, body, opts}, _from, state) do
    result = HTTPoison.request(method, url, body, headers, opts)
    {:reply, result, state}
  end
end