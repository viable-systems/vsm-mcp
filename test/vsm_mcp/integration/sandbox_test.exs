defmodule VsmMcp.Integration.SandboxTest do
  @moduledoc """
  Comprehensive tests for the security sandbox implementation.
  
  Tests:
  - Resource isolation and limits
  - File system restrictions
  - Network isolation
  - Security scanning capabilities
  - Performance monitoring
  - Dangerous operation detection
  """
  
  use ExUnit.Case, async: false
  alias VsmMcp.Integration.Sandbox
  import ExUnit.CaptureLog
  
  @test_timeout 10_000
  @test_server_config %{
    name: "test-server",
    capabilities: ["file operations", "web search"],
    version: "1.0.0"
  }
  
  setup do
    # Ensure sandbox directory exists
    sandbox_dir = "priv/sandbox"
    File.mkdir_p!(sandbox_dir)
    
    # Create test installation path
    test_install = Path.join(System.tmp_dir!(), "test_mcp_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_install)
    
    # Create minimal test server
    create_test_server(test_install)
    
    on_exit(fn ->
      File.rm_rf!(test_install)
      # Clean any remaining sandboxes
      File.ls!(sandbox_dir)
      |> Enum.filter(&String.starts_with?(&1, "sandbox_"))
      |> Enum.each(&File.rm_rf!(Path.join(sandbox_dir, &1)))
    end)
    
    {:ok, %{installation_path: test_install}}
  end
  
  describe "sandbox lifecycle" do
    test "creates and cleans up sandbox environment", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.sandbox_id
      assert result.test_results
      assert result.security_scan
      assert result.performance
      assert result.metrics
      assert is_boolean(result.passed)
      
      # Verify sandbox was cleaned up
      sandbox_path = Path.join("priv/sandbox", result.sandbox_id)
      refute File.exists?(sandbox_path)
    end
    
    test "handles server copy failures gracefully" do
      invalid_path = "/non/existent/path"
      
      assert {:error, {:copy_failed, _, _}} = 
        Sandbox.test_server(invalid_path, @test_server_config)
    end
  end
  
  describe "resource limits" do
    test "applies memory and CPU limits", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      # Verify performance metrics respect limits
      assert result.performance.memory_usage <= 512  # Max 512MB
      assert result.performance.cpu_usage <= 80      # Allow some overhead
    end
    
    test "enforces file system restrictions", %{installation_path: path} do
      # Create a server that tries to access outside sandbox
      malicious_server = create_malicious_server(path, :file_escape)
      
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      # Should detect file permission issues
      assert result.security_scan.file_permissions.status != :good
    end
  end
  
  describe "security scanning" do
    test "detects dangerous operations", %{installation_path: path} do
      # Add dangerous code patterns
      server_file = Path.join([path, "index.js"])
      dangerous_code = """
      // Dangerous operations
      eval("console.log('evil')");
      exec("rm -rf /");
      spawn_link(function() {});
      System.cmd("whoami");
      File.rm_rf("/tmp");
      """
      File.write!(server_file, dangerous_code)
      
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.security_scan.dangerous_operations.total > 0
      assert result.security_scan.score < 100
    end
    
    test "scans for vulnerable dependencies", %{installation_path: path} do
      # Create package.json with known vulnerable package
      package_json = %{
        "name" => "test-server",
        "version" => "1.0.0",
        "dependencies" => %{
          "lodash" => "3.10.1",  # Old version with vulnerabilities
          "express" => "3.0.0"   # Old version
        }
      }
      
      File.write!(
        Path.join(path, "package.json"),
        Jason.encode!(package_json, pretty: true)
      )
      
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.security_scan.dependencies.checked
      assert result.security_scan.dependencies.total == 2
    end
    
    test "checks file permissions", %{installation_path: path} do
      # Create file with dangerous permissions
      dangerous_file = Path.join(path, "dangerous.sh")
      File.write!(dangerous_file, "#!/bin/bash\necho 'test'")
      File.chmod!(dangerous_file, 0o777)
      
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.security_scan.file_permissions.status == :warning
      assert length(result.security_scan.file_permissions.issues) > 0
    end
  end
  
  describe "protocol compliance testing" do
    test "validates MCP protocol responses", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      protocol_tests = Enum.filter(result.test_results, &(&1.test.type == :protocol))
      assert length(protocol_tests) > 0
      
      # All protocol tests should pass for valid server
      assert Enum.all?(protocol_tests, & &1.passed)
    end
    
    test "tests capability-specific operations", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      capability_tests = Enum.filter(result.test_results, &(&1.test.type == :capability))
      assert length(capability_tests) > 0
    end
  end
  
  describe "performance monitoring" do
    test "measures startup time", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.performance.startup_time
      assert is_number(result.performance.startup_time)
    end
    
    test "tracks response times", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert is_list(result.performance.response_times)
      assert result.metrics.avg_response_time >= 0
    end
    
    test "monitors resource usage", %{installation_path: path} do
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      assert result.metrics.memory_usage_mb > 0
      assert result.metrics.cpu_usage_percent > 0
      assert result.metrics.cpu_usage_percent <= 100
    end
  end
  
  describe "error handling" do
    test "handles server startup failures", %{installation_path: path} do
      # Create broken start script
      File.write!(Path.join(path, "start.sh"), "exit 1")
      File.chmod!(Path.join(path, "start.sh"), 0o755)
      
      {:ok, result} = Sandbox.test_server(path, @test_server_config)
      
      startup_test = Enum.find(result.test_results, &(&1.test.name == "startup"))
      refute startup_test.passed
    end
    
    test "handles timeout during tests", %{installation_path: path} do
      # Create slow server
      slow_server = """
      #!/bin/bash
      sleep 30
      """
      File.write!(Path.join(path, "start.sh"), slow_server)
      File.chmod!(Path.join(path, "start.sh"), 0o755)
      
      # Should complete within timeout
      assert {:ok, _} = Sandbox.test_server(path, @test_server_config)
    end
  end
  
  describe "capability testing" do
    test "generates appropriate test cases for capabilities" do
      test_case = Sandbox.generate_capability_test_case("file operations")
      assert test_case.method == "file/read"
      assert test_case.expected_error == "not_found"
      
      test_case = Sandbox.generate_capability_test_case("web search")
      assert test_case.method == "search/query"
      assert Map.has_key?(test_case, :expected_fields)
      
      test_case = Sandbox.generate_capability_test_case("unknown")
      assert test_case.method == "test/echo"
    end
    
    test "executes capability-specific tests", %{installation_path: path} do
      # Test specific capability
      sandbox_id = "test_sandbox_#{:rand.uniform(10000)}"
      sandbox_path = Path.join("priv/sandbox", sandbox_id)
      File.mkdir_p!(sandbox_path)
      File.cp_r!(path, Path.join(sandbox_path, "server"))
      
      try do
        test_case = %{
          method: "test/echo",
          params: %{message: "hello"},
          expected_result: %{message: "hello"}
        }
        
        assert {:ok, result} = 
          Sandbox.test_capability(sandbox_path, "echo", test_case)
      after
        File.rm_rf!(sandbox_path)
      end
    end
  end
  
  # Helper functions
  
  defp create_test_server(path) do
    # Create minimal MCP server structure
    server_files = [
      {"start.sh", """
      #!/bin/bash
      echo '{"jsonrpc":"2.0","result":{"name":"test-server"},"id":1}'
      """},
      {"index.js", """
      console.log('Test MCP Server');
      """},
      {"package.json", Jason.encode!(%{
        name: "test-mcp-server",
        version: "1.0.0",
        dependencies: %{}
      })}
    ]
    
    for {file, content} <- server_files do
      file_path = Path.join(path, file)
      File.write!(file_path, content)
      if String.ends_with?(file, ".sh") do
        File.chmod!(file_path, 0o755)
      end
    end
  end
  
  defp create_malicious_server(path, :file_escape) do
    malicious_script = """
    #!/bin/bash
    # Try to escape sandbox
    cat /etc/passwd > ../../escaped.txt
    """
    
    File.write!(Path.join(path, "malicious.sh"), malicious_script)
    File.chmod!(Path.join(path, "malicious.sh"), 0o755)
  end
end