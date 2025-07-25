defmodule VsmMcp.AutonomousLoopIntegration do
  @moduledoc """
  Complete autonomous loop integration that connects:
  - Variety gap detection
  - LLM as external variety source
  - MCP server discovery
  - Installation
  - Execution
  - Result delivery
  
  This module makes the VSM truly autonomous.
  """
  
  use GenServer
  require Logger
  
  alias VsmMcp.LLM.Integration, as: LLM
  alias VsmMcp.MCP.BulletproofExecutor
  alias VsmMcp.Core.MCPDiscovery
  alias VsmMcp.DaemonMode
  
  @loop_timeout 120_000  # 2 minutes for complete loop
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Execute the complete autonomous loop for a capability
  """
  def autonomous_capability_acquisition(capability) do
    GenServer.call(__MODULE__, {:acquire_and_use, capability}, @loop_timeout)
  end
  
  @doc """
  Handle a variety gap autonomously - THE COMPLETE LOOP
  """
  def handle_variety_gap(gap_info) do
    GenServer.call(__MODULE__, {:handle_gap, gap_info}, @loop_timeout)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Start the bulletproof executor
    {:ok, _} = BulletproofExecutor.start_link()
    
    state = %{
      active_loops: %{},
      completed_acquisitions: [],
      metrics: %{
        loops_initiated: 0,
        loops_completed: 0,
        loops_failed: 0,
        average_loop_time: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:acquire_and_use, capability}, from, state) do
    # Start the complete loop asynchronously
    loop_id = generate_loop_id()
    
    Task.start(fn ->
      result = execute_complete_loop(capability)
      GenServer.reply(from, result)
    end)
    
    new_state = track_loop_start(state, loop_id, capability)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:handle_gap, gap_info}, from, state) do
    # Extract needed capabilities from gap
    capabilities = analyze_gap_capabilities(gap_info)
    
    # Execute loops for all needed capabilities
    Task.start(fn ->
      results = Enum.map(capabilities, &execute_complete_loop/1)
      GenServer.reply(from, {:ok, results})
    end)
    
    {:noreply, state}
  end
  
  # The Complete Autonomous Loop Implementation
  
  defp execute_complete_loop(capability) do
    start_time = System.monotonic_time(:millisecond)
    
    Logger.info("🔄 STARTING COMPLETE AUTONOMOUS LOOP: #{capability}")
    
    try do
      # Step 1: LLM Research (External Variety Source)
      {:ok, llm_research} = research_with_llm(capability)
      
      # Step 2: Discover real MCP servers based on LLM research
      {:ok, servers} = discover_servers(capability, llm_research)
      
      # Step 3: LLM selects best server
      {:ok, selected_server} = select_with_llm(servers, capability, llm_research)
      
      # Step 4: Install the MCP server
      {:ok, installation} = install_server(selected_server)
      
      # Step 5: Execute capability through the server
      {:ok, execution_result} = execute_capability(capability, selected_server, installation)
      
      duration = System.monotonic_time(:millisecond) - start_time
      
      Logger.info("✅ LOOP COMPLETE in #{duration}ms: #{capability}")
      
      {:ok, %{
        capability: capability,
        server_used: selected_server.name,
        execution_result: execution_result,
        duration_ms: duration,
        loop_stages: [
          {:llm_research, :completed},
          {:discovery, :completed},
          {:selection, :completed},
          {:installation, :completed},
          {:execution, :completed}
        ]
      }}
      
    rescue
      e ->
        Logger.error("❌ Loop failed: #{Exception.message(e)}")
        {:error, %{
          capability: capability,
          error: Exception.message(e),
          stage_failed: identify_failure_stage(e)
        }}
    end
  end
  
  defp research_with_llm(capability) do
    Logger.info("  1️⃣ LLM researching: #{capability}")
    
    LLM.process_operation(%{
      type: :research_mcp_servers,
      target: capability,
      query: """
      Find MCP (Model Context Protocol) servers that can handle #{capability}.
      Search npm registry, GitHub, and other sources.
      Return specific package names and their capabilities.
      Focus on packages like @modelcontextprotocol/server-* or mcp-server-*.
      """
    })
  end
  
  defp discover_servers(capability, llm_research) do
    Logger.info("  2️⃣ Discovering servers based on LLM research")
    
    # Extract package names from LLM research
    suggested_packages = extract_packages_from_llm(llm_research)
    
    # Use MCPDiscovery to validate and find these servers
    case MCPDiscovery.discover_servers([capability | suggested_packages]) do
      {:ok, []} ->
        # If no servers found, create a mock based on LLM suggestion
        {:ok, create_llm_suggested_servers(suggested_packages, capability)}
      {:ok, servers} ->
        {:ok, servers}
    end
  end
  
  defp select_with_llm(servers, capability, llm_research) do
    Logger.info("  3️⃣ LLM selecting best server from #{length(servers)} options")
    
    {:ok, selection_analysis} = LLM.process_operation(%{
      type: :select_best_mcp_server,
      servers: servers,
      target: capability,
      research: llm_research
    })
    
    # For now, use the first server (in production, parse LLM's choice)
    selected = List.first(servers) || %{
      name: "@modelcontextprotocol/server-#{capability}",
      description: "LLM-suggested server for #{capability}"
    }
    
    {:ok, selected}
  end
  
  defp install_server(server_info) do
    Logger.info("  4️⃣ Installing: #{server_info.name}")
    
    install_dir = "/tmp/vsm_mcp_loop_#{:rand.uniform(10000)}"
    File.mkdir_p!(install_dir)
    
    # Initialize npm project
    System.cmd("npm", ["init", "-y"], cd: install_dir, stderr_to_stdout: true)
    
    # Install the server
    case System.cmd("npm", ["install", server_info.name], 
                   cd: install_dir, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, %{
          server: server_info,
          install_dir: install_dir,
          status: :installed
        }}
      {error, code} ->
        {:error, "Installation failed (#{code}): #{error}"}
    end
  end
  
  defp execute_capability(capability, server_info, installation) do
    Logger.info("  5️⃣ EXECUTING capability through MCP server")
    
    # Use the bulletproof executor
    BulletproofExecutor.execute_capability(capability, Map.merge(server_info, %{
      install_path: installation.install_dir
    }))
  end
  
  # Helper functions
  
  defp generate_loop_id do
    "loop_#{System.unique_integer([:positive])}_#{System.os_time(:millisecond)}"
  end
  
  defp track_loop_start(state, loop_id, capability) do
    loop_info = %{
      id: loop_id,
      capability: capability,
      started_at: DateTime.utc_now(),
      status: :running
    }
    
    put_in(state, [:active_loops, loop_id], loop_info)
    |> update_in([:metrics, :loops_initiated], &(&1 + 1))
  end
  
  defp analyze_gap_capabilities(gap_info) do
    # Extract capabilities from gap info
    gap_info[:required_capabilities] || 
    gap_info[:missing_capabilities] || 
    ["general_capability"]
  end
  
  defp extract_packages_from_llm(llm_response) do
    # Parse package names from LLM response
    # In production, use proper NLP parsing
    llm_response
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "mcp"))
    |> Enum.map(fn line ->
      case Regex.run(~r/(@?[\w-]+\/)?mcp-server-[\w-]+/, line) do
        [match] -> match
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp create_llm_suggested_servers(packages, capability) do
    Enum.map(packages, fn pkg ->
      %{
        name: pkg,
        description: "LLM-suggested server for #{capability}",
        source: :llm,
        capabilities: [capability]
      }
    end)
  end
  
  defp identify_failure_stage(exception) do
    cond do
      String.contains?(Exception.message(exception), "LLM") -> :llm_research
      String.contains?(Exception.message(exception), "discover") -> :discovery
      String.contains?(Exception.message(exception), "install") -> :installation
      String.contains?(Exception.message(exception), "execute") -> :execution
      true -> :unknown
    end
  end
end