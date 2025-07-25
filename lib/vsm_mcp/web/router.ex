defmodule VsmMcp.Web.Router do
  use Plug.Router
  
  plug Plug.Logger
  plug :match
  plug Plug.Parsers, 
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch
  
  # Health check
  get "/health" do
    status = %{
      alive: true,
      daemon: daemon_status(),
      capabilities: current_capabilities()
    }
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end
  
  # Inject variety gap - THIS TRIGGERS AUTONOMY
  post "/variety-gap" do
    gap = conn.body_params
    
    # Inject the gap
    :ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
    
    # Force immediate daemon check instead of waiting 30s
    send(Process.whereis(VsmMcp.DaemonMode), :check_variety)
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      status: "gap_injected",
      gap: gap,
      message: "Daemon will process autonomously"
    }))
  end
  
  # Get current capabilities
  get "/capabilities" do
    caps = VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{capabilities: caps}))
  end
  
  # Get daemon status
  get "/daemon" do
    status = VsmMcp.DaemonMode.get_status()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
  end
  
  # Search MCP servers
  post "/search" do
    terms = conn.body_params["terms"] || []
    servers = VsmMcp.Core.MCPDiscovery.search_servers(terms)
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{servers: servers}))
  end
  
  # List running MCP servers
  get "/mcp/servers" do
    servers = VsmMcp.MCP.ExternalServerSpawner.list_running_servers()
    
    # Convert to JSON-safe format
    json_safe_servers = Enum.map(servers, fn server ->
      %{
        id: server.id,
        package: server.package,
        status: server.status,
        pid: server.pid,
        started_at: server.started_at
      }
    end)
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{servers: json_safe_servers}))
  end
  
  # Execute task via MCP
  post "/mcp/execute" do
    capability = conn.body_params["capability"]
    task_params = conn.body_params["task"]
    
    result = VsmMcp.MCP.CapabilityRouter.execute_task(capability, task_params)
    
    case result do
      {:ok, response} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{
          success: true,
          result: response,
          capability: capability
        }))
        
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{
          success: false,
          error: inspect(reason),
          capability: capability
        }))
    end
  end
  
  # Get MCP capabilities
  get "/mcp/capabilities" do
    capabilities = VsmMcp.MCP.CapabilityRouter.list_capabilities()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{capabilities: capabilities}))
  end
  
  post "/mcp/refresh" do
    # Trigger dynamic capability discovery
    VsmMcp.MCP.CapabilityRouter.refresh_capabilities()
    Process.sleep(1000) # Give it time to discover
    
    capabilities = VsmMcp.MCP.CapabilityRouter.list_capabilities()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      message: "Capabilities refreshed",
      capabilities: capabilities
    }))
  end
  
  # Force autonomous action
  post "/autonomy/trigger" do
    # Create a critical gap
    gap = %{
      type: :capability_gap,
      severity: :critical,
      required_capabilities: conn.body_params["capabilities"] || ["database"],
      source: "http_api",
      timestamp: DateTime.utc_now()
    }
    
    # Inject and trigger
    :ok = VsmMcp.Integration.VarietyDetector.inject_variety_gap(gap)
    send(Process.whereis(VsmMcp.DaemonMode), :check_variety)
    
    # Immediate response - don't wait for processing
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      triggered: true,
      gap: gap,
      message: "Autonomous acquisition triggered. Check /daemon for status."
    }))
  end
  
  # Default 404
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end
  
  defp daemon_status do
    case Process.whereis(VsmMcp.DaemonMode) do
      nil -> "not_running"
      pid when is_pid(pid) -> 
        status = VsmMcp.DaemonMode.get_status()
        %{
          running: true,
          state: status.state,
          monitoring: status.monitoring_active,
          actions: status[:autonomous_actions_count] || 0
        }
    end
  end
  
  defp current_capabilities do
    VsmMcp.Integration.CapabilityMatcher.get_all_capabilities()
  rescue
    _ -> []
  end
end