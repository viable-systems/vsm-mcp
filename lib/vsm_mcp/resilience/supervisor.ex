defmodule VsmMcp.Resilience.Supervisor do
  @moduledoc """
  Supervisor for resilience components.
  
  Manages circuit breakers, retry mechanisms, and dead letter queues.
  """
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # Global dead letter queue
      {VsmMcp.Resilience.DeadLetterQueue, name: VsmMcp.Resilience.DeadLetterQueue},
      
      # Circuit breakers will be started dynamically per service
      {DynamicSupervisor, name: VsmMcp.Resilience.CircuitBreakerSupervisor, strategy: :one_for_one},
      
      # Telemetry reporter for resilience metrics
      {VsmMcp.Resilience.TelemetryReporter, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Start a circuit breaker under supervision.
  """
  def start_circuit_breaker(name, config) do
    DynamicSupervisor.start_child(
      VsmMcp.Resilience.CircuitBreakerSupervisor,
      {VsmMcp.Resilience.CircuitBreaker, name: name, config: config}
    )
  end
end