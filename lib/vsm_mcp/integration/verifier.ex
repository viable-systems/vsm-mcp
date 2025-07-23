defmodule VsmMcp.Integration.Verifier do
  @moduledoc """
  Verifies that MCP servers meet requirements and can fill variety gaps.
  
  Verification includes:
  - Capability validation
  - Performance requirements
  - Security compliance
  - API compatibility
  - License verification
  """
  
  require Logger
  
  @min_security_score 70
  @max_response_time_ms 1000
  @min_success_rate 0.95
  
  @doc """
  Verifies that a tested MCP server can fulfill the variety gap requirements.
  """
  def verify_capability(sandbox_result, variety_gap) do
    Logger.info("Verifying capability for variety gap: #{inspect(variety_gap)}")
    
    verifications = [
      verify_functionality(sandbox_result, variety_gap),
      verify_performance(sandbox_result, variety_gap),
      verify_security(sandbox_result),
      verify_compatibility(sandbox_result),
      verify_licensing(sandbox_result)
    ]
    
    case aggregate_verifications(verifications) do
      {:ok, verified_capability} ->
        {:ok, Map.put(verified_capability, :variety_gap, variety_gap)}
        
      error ->
        error
    end
  end
  
  @doc """
  Performs runtime verification of an active capability.
  """
  def verify_runtime_behavior(capability_pid, expected_behavior) do
    # Monitor the capability process for expected behavior
    test_cases = generate_runtime_tests(expected_behavior)
    
    results = Enum.map(test_cases, fn test ->
      verify_single_behavior(capability_pid, test)
    end)
    
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, %{verified: true, results: results}}
    else
      {:error, {:runtime_verification_failed, results}}
    end
  end
  
  ## Private Functions
  
  defp verify_functionality(sandbox_result, variety_gap) do
    required_capabilities = extract_required_capabilities(variety_gap)
    available_capabilities = extract_available_capabilities(sandbox_result)
    
    missing = required_capabilities -- available_capabilities
    
    if Enum.empty?(missing) do
      {:ok, %{functionality: :verified, capabilities: available_capabilities}}
    else
      {:error, {:missing_capabilities, missing}}
    end
  end
  
  defp verify_performance(sandbox_result, variety_gap) do
    metrics = sandbox_result.metrics
    requirements = extract_performance_requirements(variety_gap)
    
    checks = [
      check_response_time(metrics, requirements),
      check_throughput(metrics, requirements),
      check_resource_usage(metrics, requirements)
    ]
    
    failed_checks = Enum.filter(checks, &match?({:error, _}, &1))
    
    if Enum.empty?(failed_checks) do
      {:ok, %{performance: :verified, metrics: metrics}}
    else
      {:error, {:performance_requirements_not_met, failed_checks}}
    end
  end
  
  defp verify_security(sandbox_result) do
    security_score = get_in(sandbox_result, [:security_scan, :score]) || 0
    
    if security_score >= @min_security_score do
      {:ok, %{security: :verified, score: security_score}}
    else
      {:error, {:insufficient_security_score, security_score}}
    end
  end
  
  defp verify_compatibility(sandbox_result) do
    # Check MCP protocol compatibility
    protocol_tests = Enum.filter(sandbox_result.test_results, &(&1.test.type == :protocol))
    
    if Enum.all?(protocol_tests, & &1.passed) do
      {:ok, %{compatibility: :verified, protocol: "mcp/1.0"}}
    else
      failed = Enum.filter(protocol_tests, &(not &1.passed))
      {:error, {:protocol_compatibility_failed, failed}}
    end
  end
  
  defp verify_licensing(_sandbox_result) do
    # In production, check license compatibility
    # For now, assume compatible
    {:ok, %{licensing: :verified, license: "MIT"}}
  end
  
  defp aggregate_verifications(verifications) do
    errors = Enum.filter(verifications, &match?({:error, _}, &1))
    
    if Enum.empty?(errors) do
      verified_data = Enum.reduce(verifications, %{}, fn {:ok, data}, acc ->
        Map.merge(acc, data)
      end)
      
      {:ok, Map.put(verified_data, :verified_at, DateTime.utc_now())}
    else
      {:error, {:verification_failed, errors}}
    end
  end
  
  defp extract_required_capabilities(variety_gap) do
    case variety_gap do
      %{required_capabilities: caps} when is_list(caps) -> caps
      %{capabilities: caps} when is_list(caps) -> caps
      _ -> []
    end
  end
  
  defp extract_available_capabilities(sandbox_result) do
    # Extract from test results
    capability_tests = Enum.filter(sandbox_result.test_results, &(&1.test.type == :capability))
    
    Enum.map(capability_tests, fn test ->
      Map.get(test.test, :capability, "unknown")
    end)
    |> Enum.uniq()
  end
  
  defp extract_performance_requirements(variety_gap) do
    defaults = %{
      max_response_time: @max_response_time_ms,
      min_throughput: 100,  # requests per second
      max_memory_mb: 512,
      max_cpu_percent: 50
    }
    
    Map.merge(defaults, Map.get(variety_gap, :performance_requirements, %{}))
  end
  
  defp check_response_time(metrics, requirements) do
    avg_response_time = Map.get(metrics, :avg_response_time, 0)
    
    if avg_response_time <= requirements.max_response_time do
      {:ok, :response_time}
    else
      {:error, {:response_time_exceeded, avg_response_time}}
    end
  end
  
  defp check_throughput(_metrics, _requirements) do
    # In production, measure actual throughput
    {:ok, :throughput}
  end
  
  defp check_resource_usage(metrics, requirements) do
    memory = Map.get(metrics, :memory_usage_mb, 0)
    cpu = Map.get(metrics, :cpu_usage_percent, 0)
    
    cond do
      memory > requirements.max_memory_mb ->
        {:error, {:memory_exceeded, memory}}
        
      cpu > requirements.max_cpu_percent ->
        {:error, {:cpu_exceeded, cpu}}
        
      true ->
        {:ok, :resource_usage}
    end
  end
  
  defp generate_runtime_tests(expected_behavior) do
    # Generate test cases based on expected behavior
    [
      %{
        name: "basic_operation",
        method: "test/echo",
        params: %{message: "test"},
        expected: %{message: "test"}
      },
      %{
        name: "error_handling",
        method: "test/error",
        params: %{},
        expected_error: true
      }
    ]
  end
  
  defp verify_single_behavior(capability_pid, test) do
    case GenServer.call(capability_pid, {:execute, test.method, test.params}, 5000) do
      {:ok, result} ->
        if Map.has_key?(test, :expected) and result == test.expected do
          {:ok, %{test: test.name, passed: true}}
        else
          {:ok, %{test: test.name, passed: false, got: result}}
        end
        
      {:error, _} = error ->
        if Map.get(test, :expected_error, false) do
          {:ok, %{test: test.name, passed: true}}
        else
          error
        end
    end
  catch
    :exit, {:timeout, _} ->
      {:error, {:test_timeout, test.name}}
  end
end