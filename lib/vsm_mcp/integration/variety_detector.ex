defmodule VsmMcp.Integration.VarietyDetector do
  @moduledoc """
  Real-time variety gap detection and injection mechanism.
  THIS IS WHERE THE MAGIC HAPPENS!
  """
  use GenServer
  require Logger

  alias VsmMcp.Core.VarietyCalculator

  @variety_threshold 0.85
  @check_interval 5_000  # 5 seconds for rapid detection

  defstruct [
    :current_variety,
    :required_variety,
    :injected_gaps,
    :detection_active,
    :listeners
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def inject_variety_gap(gap_info) do
    GenServer.cast(__MODULE__, {:inject_gap, gap_info})
  end

  def get_current_gap do
    GenServer.call(__MODULE__, :get_current_gap)
  end

  def subscribe_to_gaps(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      current_variety: 0,
      required_variety: 0,
      injected_gaps: [],
      detection_active: true,
      listeners: []
    }
    
    # Start detection loop
    schedule_detection()
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:inject_gap, gap_info}, state) do
    Logger.warn("💉 Variety gap injected: #{inspect(gap_info)}")
    
    # Add to injected gaps
    updated_gaps = [gap_info | state.injected_gaps]
    
    # Notify all listeners
    Enum.each(state.listeners, fn pid ->
      send(pid, {:variety_gap_detected, gap_info})
    end)
    
    # If DaemonMode is running, notify it too
    if Process.whereis(VsmMcp.DaemonMode) do
      VsmMcp.DaemonMode.inject_variety_gap(gap_info)
    end
    
    {:noreply, %{state | injected_gaps: updated_gaps}}
  end

  @impl true
  def handle_call(:get_current_gap, _from, state) do
    gap = %{
      current: state.current_variety,
      required: state.required_variety,
      gap: state.required_variety - state.current_variety,
      ratio: state.current_variety / max(state.required_variety, 1),
      injected: state.injected_gaps
    }
    {:reply, gap, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | listeners: [pid | state.listeners]}}
  end

  @impl true
  def handle_info(:detect_variety, state) do
    # Calculate current variety
    current = VarietyCalculator.calculate()
    required = calculate_required_variety(state)
    
    new_state = %{state | 
      current_variety: current,
      required_variety: required
    }
    
    # Check for natural gaps
    ratio = current / max(required, 1)
    if ratio < @variety_threshold do
      gap_info = %{
        type: :natural_detection,
        severity: severity_from_ratio(ratio),
        current: current,
        required: required,
        gap: required - current,
        ratio: ratio,
        timestamp: DateTime.utc_now()
      }
      
      # Notify listeners
      Enum.each(state.listeners, fn pid ->
        send(pid, {:variety_gap_detected, gap_info})
      end)
    end
    
    # Schedule next detection
    schedule_detection()
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | listeners: List.delete(state.listeners, pid)}}
  end

  # Private Functions

  defp schedule_detection do
    Process.send_after(self(), :detect_variety, @check_interval)
  end

  defp calculate_required_variety(state) do
    # Base requirement
    base = 50
    
    # Add for each injected gap
    injected = length(state.injected_gaps) * 20
    
    # Add based on time of day (simulate varying load)
    time_factor = :erlang.system_time(:second) |> rem(100) |> div(10)
    
    base + injected + time_factor
  end

  defp severity_from_ratio(ratio) when ratio < 0.5, do: :critical
  defp severity_from_ratio(ratio) when ratio < 0.7, do: :high
  defp severity_from_ratio(ratio) when ratio < 0.85, do: :medium
  defp severity_from_ratio(_), do: :low
end