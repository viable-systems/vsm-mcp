defmodule VsmMcp.Telemetry do
  @moduledoc """
  Telemetry setup for VSM-MCP system monitoring.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()},
      {Telemetry.Poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # VSM System metrics
      counter("vsm.system1.operation.count"),
      counter("vsm.system2.coordination.count"),
      counter("vsm.system3.audit.count"),
      counter("vsm.system4.scan.count"),
      counter("vsm.system5.decision.count"),
      
      # Variety metrics
      last_value("vsm.variety.operational"),
      last_value("vsm.variety.environmental"),
      last_value("vsm.variety.gap"),
      
      # Consciousness metrics
      counter("vsm.consciousness.reflection.count"),
      counter("vsm.consciousness.learning.count"),
      
      # Integration metrics
      counter("vsm.integration.capability.added"),
      counter("vsm.integration.capability.removed"),
      
      # MCP metrics
      counter("vsm.mcp.request.count"),
      counter("vsm.mcp.error.count"),
      summary("vsm.mcp.request.duration"),
      
      # System health
      last_value("vm.memory.total"),
      last_value("vm.total_run_queue_lengths")
    ]
  end

  defp periodic_measurements do
    [
      {[:vm, :memory], :memory, []},
      {[:vm, :total_run_queue_lengths], :total_run_queue_lengths, []}
    ]
  end
end