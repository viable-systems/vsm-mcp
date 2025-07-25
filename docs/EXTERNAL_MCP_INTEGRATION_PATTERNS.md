# External MCP Server Integration Patterns

## Overview

This document defines comprehensive patterns and strategies for integrating external MCP servers into the VSM-MCP autonomous daemon system. It covers discovery, evaluation, integration, monitoring, and lifecycle management of external MCP capabilities.

## 1. Discovery Patterns

### 1.1 Multi-Source Discovery Architecture

```elixir
defmodule VsmMcp.Integration.Discovery do
  @moduledoc """
  Multi-source discovery system for external MCP servers.
  """
  
  @discovery_sources [
    NPMRegistry,
    GitHubSearch,
    MCPRegistry,
    CommunityRecommendations,
    LLMResearch
  ]
  
  def discover_servers(requirements, options \\ []) do
    # Parallel discovery across all sources
    tasks = Enum.map(@discovery_sources, fn source ->
      Task.async(fn -> 
        source.discover(requirements, options)
      end)
    end)
    
    # Collect and merge results
    results = Task.await_many(tasks, 30_000)
    |> merge_discovery_results()
    |> deduplicate_servers()
    |> rank_by_relevance(requirements)
    |> apply_filters(options)
    
    {:ok, results}
  end
end
```

### 1.2 NPM Registry Discovery

```elixir
defmodule VsmMcp.Integration.Discovery.NPMRegistry do
  @npm_api_base "https://registry.npmjs.org"
  
  def discover(requirements, _options) do
    search_terms = generate_search_terms(requirements)
    
    results = Enum.flat_map(search_terms, fn term ->
      search_npm_packages(term)
      |> filter_mcp_packages()
      |> extract_package_info()
    end)
    
    {:ok, results}
  end
  
  defp generate_search_terms(%{capability: capability}) do
    base_terms = [
      "mcp #{capability}",
      "model-context-protocol #{capability}",
      "#{capability} mcp server"
    ]
    
    # Add capability-specific terms
    case capability do
      "document_generation" -> 
        base_terms ++ ["mcp document", "mcp pdf", "mcp office"]
      "image_processing" -> 
        base_terms ++ ["mcp image", "mcp graphics", "mcp vision"]
      "data_analysis" -> 
        base_terms ++ ["mcp analytics", "mcp statistics", "mcp ml"]
      _ -> 
        base_terms
    end
  end
  
  defp search_npm_packages(term) do
    url = "#{@npm_api_base}/-/v1/search"
    params = %{
      text: term,
      size: 20,
      quality: 0.8,
      popularity: 0.1,
      maintenance: 0.1
    }
    
    case HTTPoison.get(url, [], params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode!(body)["objects"]
      _ ->
        []
    end
  end
  
  defp filter_mcp_packages(packages) do
    Enum.filter(packages, fn package ->
      package_info = package["package"]
      
      # Check if it's likely an MCP server
      keywords = package_info["keywords"] || []
      description = package_info["description"] || ""
      name = package_info["name"]
      
      mcp_indicators = [
        "mcp" in keywords,
        "model-context-protocol" in keywords,
        String.contains?(description, "mcp"),
        String.contains?(name, "mcp"),
        String.contains?(description, "model context protocol")
      ]
      
      Enum.any?(mcp_indicators)
    end)
  end
  
  defp extract_package_info(packages) do
    Enum.map(packages, fn package ->
      package_info = package["package"]
      
      %{
        source: :npm,
        name: package_info["name"],
        version: package_info["version"],
        description: package_info["description"],
        keywords: package_info["keywords"] || [],
        author: get_author_name(package_info["author"]),
        repository: package_info["repository"]["url"] || nil,
        homepage: package_info["homepage"],
        license: package_info["license"],
        download_count: package["downloads"]["monthly"],
        last_updated: package_info["date"],
        npm_score: package["score"]["final"],
        quality_score: package["score"]["detail"]["quality"],
        popularity_score: package["score"]["detail"]["popularity"],
        maintenance_score: package["score"]["detail"]["maintenance"]
      }
    end)
  end
end
```

### 1.3 GitHub Repository Discovery

```elixir
defmodule VsmMcp.Integration.Discovery.GitHubSearch do
  @github_api_base "https://api.github.com"
  
  def discover(requirements, _options) do
    search_queries = generate_github_queries(requirements)
    
    results = Enum.flat_map(search_queries, fn query ->
      search_github_repositories(query)
      |> filter_mcp_repositories()
      |> extract_repository_info()
    end)
    
    {:ok, results}
  end
  
  defp generate_github_queries(%{capability: capability}) do
    [
      "mcp server #{capability}",
      "model context protocol #{capability}",
      "#{capability} in:readme mcp",
      "mcp tool #{capability} language:javascript",
      "mcp tool #{capability} language:python",
      "mcp tool #{capability} language:typescript"
    ]
  end
  
  defp search_github_repositories(query) do
    url = "#{@github_api_base}/search/repositories"
    headers = [
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "VSM-MCP-Discovery"}
    ]
    
    # Add GitHub token if available
    headers = case System.get_env("GITHUB_TOKEN") do
      nil -> headers
      token -> [{"Authorization", "token #{token}"} | headers]
    end
    
    params = %{
      q: query,
      sort: "stars",
      order: "desc",
      per_page: 30
    }
    
    case HTTPoison.get(url, headers, params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode!(body)["items"]
      _ ->
        []
    end
  end
  
  defp filter_mcp_repositories(repositories) do
    Enum.filter(repositories, fn repo ->
      # Check repository indicators
      description = repo["description"] || ""
      readme_content = fetch_readme_content(repo["full_name"])
      
      mcp_indicators = [
        String.contains?(description, "mcp"),
        String.contains?(readme_content, "model context protocol"),
        String.contains?(readme_content, "mcp server"),
        has_mcp_files?(repo["full_name"])
      ]
      
      Enum.any?(mcp_indicators)
    end)
  end
  
  defp extract_repository_info(repositories) do
    Enum.map(repositories, fn repo ->
      %{
        source: :github,
        name: repo["name"],
        full_name: repo["full_name"],
        description: repo["description"],
        clone_url: repo["clone_url"],
        ssh_url: repo["ssh_url"],
        homepage: repo["homepage"],
        language: repo["language"],
        stars: repo["stargazers_count"],
        forks: repo["forks_count"],
        open_issues: repo["open_issues_count"],
        license: get_license_name(repo["license"]),
        last_updated: repo["updated_at"],
        created_at: repo["created_at"],
        topics: repo["topics"] || [],
        size_kb: repo["size"],
        default_branch: repo["default_branch"]
      }
    end)
  end
end
```

### 1.4 LLM-Assisted Discovery

```elixir
defmodule VsmMcp.Integration.Discovery.LLMResearch do
  alias VsmMcp.LLM.Integration
  
  def discover(requirements, _options) do
    # Use LLM to research and recommend MCP servers
    research_prompt = build_research_prompt(requirements)
    
    case Integration.process_operation(%{
      type: :research_mcp_servers,
      prompt: research_prompt,
      requirements: requirements
    }) do
      {:ok, research_results} ->
        servers = parse_llm_recommendations(research_results)
        |> validate_recommendations()
        |> enrich_with_metadata()
        
        {:ok, servers}
        
      {:error, reason} ->
        Logger.warning("LLM research failed: #{inspect(reason)}")
        {:ok, []}
    end
  end
  
  defp build_research_prompt(requirements) do
    """
    Research available MCP (Model Context Protocol) servers that can provide the following capability: #{requirements.capability}
    
    Please search for and recommend MCP servers from these sources:
    1. NPM packages with "mcp" in the name or keywords
    2. GitHub repositories implementing MCP servers
    3. Official MCP registry or documentation
    4. Community recommendations and known implementations
    
    For each server found, provide:
    - Name and installation method
    - Capabilities and tools provided
    - Installation instructions
    - Compatibility and requirements
    - Community adoption and maintenance status
    - Security considerations
    
    Focus on servers that are:
    - Actively maintained
    - Well-documented
    - Have good community adoption
    - Follow MCP protocol standards
    - Are compatible with Node.js/npm ecosystem
    
    Return results in JSON format with detailed information for evaluation.
    """
  end
  
  defp parse_llm_recommendations(research_results) do
    # Parse LLM response and extract server recommendations
    case Jason.decode(research_results) do
      {:ok, data} when is_list(data) ->
        Enum.map(data, &convert_llm_recommendation/1)
      {:ok, %{"servers" => servers}} when is_list(servers) ->
        Enum.map(servers, &convert_llm_recommendation/1)
      _ ->
        # Fallback parsing for unstructured response
        parse_unstructured_response(research_results)
    end
  end
  
  defp convert_llm_recommendation(recommendation) do
    %{
      source: :llm_research,
      name: recommendation["name"],
      description: recommendation["description"],
      installation_method: recommendation["installation_method"],
      capabilities: recommendation["capabilities"] || [],
      npm_package: recommendation["npm_package"],
      github_url: recommendation["github_url"],
      documentation: recommendation["documentation"],
      maintenance_status: recommendation["maintenance_status"],
      community_rating: recommendation["community_rating"],
      security_notes: recommendation["security_notes"],
      llm_confidence: recommendation["confidence"] || 0.5
    }
  end
end
```

## 2. Evaluation and Ranking Patterns

### 2.1 Multi-Criteria Evaluation

```elixir
defmodule VsmMcp.Integration.Evaluation do
  @evaluation_criteria [
    :capability_match,
    :security_score,
    :performance_rating,
    :maintenance_quality,
    :community_adoption,
    :compatibility,
    :documentation_quality,
    :license_compatibility
  ]
  
  def evaluate_servers(servers, requirements) do
    Enum.map(servers, fn server ->
      scores = Enum.reduce(@evaluation_criteria, %{}, fn criterion, acc ->
        score = evaluate_criterion(server, criterion, requirements)
        Map.put(acc, criterion, score)
      end)
      
      overall_score = calculate_weighted_score(scores, requirements)
      
      Map.merge(server, %{
        evaluation_scores: scores,
        overall_score: overall_score,
        evaluation_timestamp: DateTime.utc_now()
      })
    end)
    |> Enum.sort_by(& &1.overall_score, :desc)
  end
  
  defp evaluate_criterion(server, :capability_match, requirements) do
    # Analyze how well server capabilities match requirements
    server_capabilities = extract_capabilities(server)
    required_capabilities = requirements.capabilities || [requirements.capability]
    
    matches = Enum.count(required_capabilities, fn req_cap ->
      Enum.any?(server_capabilities, &capability_matches?(&1, req_cap))
    end)
    
    matches / max(length(required_capabilities), 1)
  end
  
  defp evaluate_criterion(server, :security_score, _requirements) do
    # Security evaluation based on multiple factors
    factors = [
      has_security_policy?(server),
      has_vulnerability_scanning?(server),
      recent_security_updates?(server),
      trusted_author?(server),
      code_review_process?(server)
    ]
    
    security_score = Enum.count(factors, & &1) / length(factors)
    
    # Apply penalties for known issues
    penalties = [
      has_known_vulnerabilities?(server),
      outdated_dependencies?(server),
      suspicious_patterns?(server)
    ]
    
    penalty = Enum.count(penalties, & &1) * 0.2
    max(security_score - penalty, 0.0)
  end
  
  defp evaluate_criterion(server, :performance_rating, _requirements) do
    # Performance evaluation based on available metrics
    case server.source do
      :npm ->
        # Use npm download counts and ratings
        download_score = min(server.download_count / 10000, 1.0)
        quality_score = server.quality_score || 0.5
        (download_score + quality_score) / 2
        
      :github ->
        # Use GitHub stars and activity
        stars_score = min(server.stars / 100, 1.0)
        activity_score = calculate_activity_score(server)
        (stars_score + activity_score) / 2
        
      _ ->
        0.5  # Default score for unknown sources
    end
  end
  
  defp evaluate_criterion(server, :maintenance_quality, _requirements) do
    # Evaluate maintenance quality
    factors = []
    
    # Check last update recency
    factors = if recently_updated?(server) do
      [0.3 | factors]
    else
      factors
    end
    
    # Check update frequency
    factors = if regular_updates?(server) do
      [0.3 | factors]
    else
      factors
    end
    
    # Check issue response time
    factors = if responsive_maintainer?(server) do
      [0.2 | factors]
    else
      factors
    end
    
    # Check documentation quality
    factors = if good_documentation?(server) do
      [0.2 | factors]
    else
      factors
    end
    
    Enum.sum(factors)
  end
  
  defp calculate_weighted_score(scores, requirements) do
    weights = get_evaluation_weights(requirements)
    
    Enum.reduce(scores, 0.0, fn {criterion, score}, total ->
      weight = Map.get(weights, criterion, 0.1)
      total + (score * weight)
    end)
  end
  
  defp get_evaluation_weights(requirements) do
    # Adjust weights based on requirements and context
    base_weights = %{
      capability_match: 0.30,
      security_score: 0.20,
      performance_rating: 0.15,
      maintenance_quality: 0.15,
      community_adoption: 0.10,
      compatibility: 0.05,
      documentation_quality: 0.03,
      license_compatibility: 0.02
    }
    
    # Adjust weights based on priority
    case requirements[:priority] do
      :security_critical ->
        Map.merge(base_weights, %{
          security_score: 0.40,
          capability_match: 0.25
        })
        
      :performance_critical ->
        Map.merge(base_weights, %{
          performance_rating: 0.30,
          capability_match: 0.25
        })
        
      _ ->
        base_weights
    end
  end
end
```

## 3. Installation and Integration Patterns

### 3.1 Multi-Method Installation

```elixir
defmodule VsmMcp.Integration.Installation do
  @installation_methods [:npm_install, :git_clone, :local_build, :docker_run]
  
  def install_server(server, options \\ []) do
    method = determine_installation_method(server, options)
    
    case method do
      :npm_install -> install_via_npm(server, options)
      :git_clone -> install_via_git(server, options)
      :local_build -> install_via_build(server, options)
      :docker_run -> install_via_docker(server, options)
    end
  end
  
  defp determine_installation_method(server, options) do
    preferred = Keyword.get(options, :preferred_method)
    
    cond do
      preferred && method_available?(preferred, server) ->
        preferred
        
      server.source == :npm && server.npm_package ->
        :npm_install
        
      server.source == :github && server.clone_url ->
        :git_clone
        
      has_dockerfile?(server) ->
        :docker_run
        
      true ->
        :npm_install  # Fallback
    end
  end
  
  defp install_via_npm(server, options) do
    package_name = server.npm_package || server.name
    version = Keyword.get(options, :version, "latest")
    
    install_path = Path.join([
      get_installation_dir(),
      "npm",
      sanitize_name(package_name)
    ])
    
    File.mkdir_p!(install_path)
    
    # Create package.json for isolated installation
    package_json = %{
      "name" => "mcp-server-#{sanitize_name(package_name)}",
      "version" => "1.0.0",
      "dependencies" => %{
        package_name => version
      }
    }
    
    package_json_path = Path.join(install_path, "package.json")
    File.write!(package_json_path, Jason.encode!(package_json, pretty: true))
    
    # Install package
    case System.cmd("npm", ["install"], cd: install_path, stderr_to_stdout: true) do
      {output, 0} ->
        # Verify installation
        executable_path = find_executable_path(install_path, package_name)
        
        {:ok, %{
          installation_path: install_path,
          executable_path: executable_path,
          installation_method: :npm_install,
          package_name: package_name,
          version: extract_installed_version(install_path, package_name),
          installation_log: output
        }}
        
      {error_output, exit_code} ->
        {:error, "NPM installation failed (exit code: #{exit_code}): #{error_output}"}
    end
  end
  
  defp install_via_git(server, options) do
    repo_url = server.clone_url || server.ssh_url
    branch = Keyword.get(options, :branch, server.default_branch || "main")
    
    install_path = Path.join([
      get_installation_dir(),
      "git",
      sanitize_name(server.name)
    ])
    
    # Clone repository
    case System.cmd("git", ["clone", "-b", branch, repo_url, install_path], stderr_to_stdout: true) do
      {output, 0} ->
        # Install dependencies if package.json exists
        package_json_path = Path.join(install_path, "package.json")
        
        installation_result = if File.exists?(package_json_path) do
          case System.cmd("npm", ["install"], cd: install_path, stderr_to_stdout: true) do
            {npm_output, 0} ->
              {:ok, output <> "\n" <> npm_output}
            {npm_error, _} ->
              {:error, "Dependencies installation failed: #{npm_error}"}
          end
        else
          {:ok, output}
        end
        
        case installation_result do
          {:ok, full_output} ->
            {:ok, %{
              installation_path: install_path,
              executable_path: find_executable_in_repo(install_path),
              installation_method: :git_clone,
              repository_url: repo_url,
              branch: branch,
              commit_hash: get_current_commit(install_path),
              installation_log: full_output
            }}
            
          {:error, reason} ->
            # Cleanup on failure
            File.rm_rf(install_path)
            {:error, reason}
        end
        
      {error_output, exit_code} ->
        {:error, "Git clone failed (exit code: #{exit_code}): #{error_output}"}
    end
  end
  
  defp install_via_docker(server, options) do
    image_name = Keyword.get(options, :image_name, "mcp-#{server.name}")
    dockerfile_path = find_dockerfile_path(server)
    
    build_context = if server.source == :github do
      # Build from cloned repository
      temp_path = Path.join(System.tmp_dir!(), "mcp-build-#{:rand.uniform(10000)}")
      
      case System.cmd("git", ["clone", server.clone_url, temp_path]) do
        {_, 0} -> temp_path
        _ -> nil
      end
    else
      server.installation_path
    end
    
    return if build_context do
      # Build Docker image
      docker_args = [
        "build",
        "-t", image_name,
        "-f", dockerfile_path,
        build_context
      ]
      
      case System.cmd("docker", docker_args, stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, %{
            installation_path: build_context,
            installation_method: :docker_run,
            docker_image: image_name,
            dockerfile_path: dockerfile_path,
            installation_log: output
          }}
          
        {error_output, exit_code} ->
          # Cleanup
          if String.starts_with?(build_context, System.tmp_dir!()) do
            File.rm_rf(build_context)
          end
          
          {:error, "Docker build failed (exit code: #{exit_code}): #{error_output}"}
      end
    else
      {:error, "Could not prepare build context for Docker installation"}
    end
  end
end
```

### 3.2 Sandbox Testing Pattern

```elixir
defmodule VsmMcp.Integration.SandboxTesting do
  @sandbox_timeout 30_000
  
  def test_server(installation_result, server_spec) do
    sandbox_id = generate_sandbox_id()
    
    # Create isolated test environment
    with {:ok, sandbox_env} <- create_sandbox_environment(sandbox_id),
         {:ok, server_process} <- start_server_in_sandbox(installation_result, sandbox_env),
         {:ok, test_results} <- run_capability_tests(server_process, server_spec),
         {:ok, security_scan} <- run_security_scan(server_process, sandbox_env),
         {:ok, performance_metrics} <- collect_performance_metrics(server_process) do
      
      # Cleanup sandbox
      cleanup_sandbox(sandbox_env)
      
      {:ok, %{
        sandbox_id: sandbox_id,
        test_results: test_results,
        security_scan: security_scan,
        performance_metrics: performance_metrics,
        server_compatibility: assess_compatibility(test_results),
        recommendation: generate_recommendation(test_results, security_scan, performance_metrics)
      }}
    else
      {:error, reason} ->
        cleanup_sandbox_on_error(sandbox_id)
        {:error, reason}
    end
  end
  
  defp create_sandbox_environment(sandbox_id) do
    sandbox_path = Path.join([
      get_sandbox_dir(),
      sandbox_id
    ])
    
    File.mkdir_p!(sandbox_path)
    
    # Create restricted environment
    env_config = %{
      sandbox_id: sandbox_id,
      sandbox_path: sandbox_path,
      network_restrictions: create_network_restrictions(),
      file_system_restrictions: create_filesystem_restrictions(sandbox_path),
      resource_limits: create_resource_limits(),
      security_constraints: create_security_constraints()
    }
    
    {:ok, env_config}
  end
  
  defp start_server_in_sandbox(installation_result, sandbox_env) do
    # Start MCP server with sandbox restrictions
    server_config = %{
      executable: installation_result.executable_path,
      working_dir: sandbox_env.sandbox_path,
      environment: build_sandbox_environment_vars(sandbox_env),
      resource_limits: sandbox_env.resource_limits,
      network_policy: sandbox_env.network_restrictions,
      timeout: @sandbox_timeout
    }
    
    case VsmMcp.MCP.ServerManager.start_sandboxed_server(server_config) do
      {:ok, server_process} ->
        # Wait for server to initialize
        Process.sleep(2000)
        
        # Verify server is responding
        case ping_server(server_process) do
          :ok -> {:ok, server_process}
          {:error, reason} -> {:error, "Server not responding: #{reason}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to start server in sandbox: #{reason}"}
    end
  end
  
  defp run_capability_tests(server_process, server_spec) do
    # Test basic MCP protocol compliance
    protocol_tests = [
      test_initialize_handshake(server_process),
      test_list_tools(server_process),
      test_list_resources(server_process),
      test_list_prompts(server_process)
    ]
    
    # Test specific capabilities
    capability_tests = if server_spec.expected_capabilities do
      Enum.map(server_spec.expected_capabilities, fn capability ->
        test_capability(server_process, capability)
      end)
    else
      []
    end
    
    # Test error handling
    error_handling_tests = [
      test_invalid_request_handling(server_process),
      test_timeout_handling(server_process),
      test_malformed_input_handling(server_process)
    ]
    
    all_tests = protocol_tests ++ capability_tests ++ error_handling_tests
    
    results = %{
      protocol_compliance: analyze_protocol_tests(protocol_tests),
      capability_verification: analyze_capability_tests(capability_tests),
      error_handling: analyze_error_tests(error_handling_tests),
      overall_success_rate: calculate_success_rate(all_tests),
      test_details: all_tests
    }
    
    {:ok, results}
  end
  
  defp run_security_scan(server_process, sandbox_env) do
    # Network activity monitoring
    network_scan = monitor_network_activity(server_process, 10_000)
    
    # File system access monitoring
    filesystem_scan = monitor_filesystem_access(sandbox_env, 10_000)
    
    # Process monitoring
    process_scan = monitor_process_behavior(server_process, 10_000)
    
    # Static analysis of server code
    static_scan = perform_static_security_analysis(sandbox_env.sandbox_path)
    
    security_results = %{
      network_activity: network_scan,
      filesystem_access: filesystem_scan,
      process_behavior: process_scan,
      static_analysis: static_scan,
      security_score: calculate_security_score(network_scan, filesystem_scan, process_scan, static_scan),
      vulnerabilities: identify_vulnerabilities(static_scan),
      risk_assessment: assess_security_risk(network_scan, filesystem_scan, process_scan)
    }
    
    {:ok, security_results}
  end
  
  defp collect_performance_metrics(server_process) do
    # Measure response times
    response_times = measure_response_times(server_process)
    
    # Measure resource usage
    resource_usage = measure_resource_usage(server_process)
    
    # Measure throughput
    throughput = measure_throughput(server_process)
    
    # Measure memory consumption
    memory_usage = measure_memory_usage(server_process)
    
    performance_results = %{
      response_times: response_times,
      resource_usage: resource_usage,
      throughput: throughput,
      memory_usage: memory_usage,
      performance_score: calculate_performance_score(response_times, resource_usage, throughput),
      bottlenecks: identify_bottlenecks(response_times, resource_usage),
      scalability_assessment: assess_scalability(throughput, memory_usage)
    }
    
    {:ok, performance_results}
  end
end
```

## 4. Dynamic Integration Patterns

### 4.1 Hot Integration Pattern

```elixir
defmodule VsmMcp.Integration.HotIntegration do
  @moduledoc """
  Enables hot integration of MCP servers without system downtime.
  """
  
  def integrate_server_hot(server_info, integration_config) do
    integration_id = generate_integration_id()
    
    # Phase 1: Prepare integration
    with {:ok, prepared} <- prepare_integration(server_info, integration_config),
         # Phase 2: Install and verify
         {:ok, installed} <- install_and_verify(prepared),
         # Phase 3: Create adapter
         {:ok, adapter} <- create_protocol_adapter(installed),
         # Phase 4: Warm up server
         {:ok, warmed_up} <- warm_up_server(adapter),
         # Phase 5: Route traffic gradually
         {:ok, integrated} <- gradual_traffic_routing(warmed_up, integration_config) do
      
      # Phase 6: Complete integration
      complete_integration(integrated, integration_id)
    else
      {:error, phase, reason} ->
        rollback_integration(integration_id, phase, reason)
    end
  end
  
  defp gradual_traffic_routing(server_info, config) do
    traffic_percentages = [5, 15, 30, 50, 75, 100]
    
    Enum.reduce_while(traffic_percentages, {:ok, server_info}, fn percentage, {:ok, current_info} ->
      Logger.info("Routing #{percentage}% traffic to new MCP server")
      
      # Update traffic routing
      case update_traffic_routing(current_info.server_id, percentage) do
        :ok ->
          # Monitor for issues during this percentage
          case monitor_integration_health(current_info.server_id, 30_000) do
            {:ok, health_metrics} ->
              if health_metrics.success_rate > 0.95 do
                {:cont, {:ok, Map.put(current_info, :traffic_percentage, percentage)}}
              else
                Logger.error("Health check failed at #{percentage}% traffic")
                {:halt, {:error, :health_check_failed, health_metrics}}
              end
              
            {:error, reason} ->
              {:halt, {:error, :monitoring_failed, reason}}
          end
          
        {:error, reason} ->
          {:halt, {:error, :traffic_routing_failed, reason}}
      end
    end)
  end
  
  defp update_traffic_routing(server_id, percentage) do
    # Update load balancer configuration
    VsmMcp.MCP.LoadBalancer.update_server_weight(server_id, percentage)
  end
  
  defp monitor_integration_health(server_id, duration) do
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration
    
    monitor_integration_health_loop(server_id, end_time, [])
  end
  
  defp monitor_integration_health_loop(server_id, end_time, metrics_history) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time >= end_time do
      # Calculate overall health metrics
      health_summary = calculate_health_summary(metrics_history)
      {:ok, health_summary}
    else
      # Collect current metrics
      case collect_server_metrics(server_id) do
        {:ok, metrics} ->
          new_history = [metrics | metrics_history]
          
          # Check for immediate issues
          if metrics.error_rate > 0.1 do
            {:error, :high_error_rate}
          else
            Process.sleep(5000)  # Wait 5 seconds before next check
            monitor_integration_health_loop(server_id, end_time, new_history)
          end
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
```

### 4.2 Capability Mapping Pattern

```elixir
defmodule VsmMcp.Integration.CapabilityMapping do
  @moduledoc """
  Maps external MCP server capabilities to VSM system requirements.
  """
  
  def map_server_capabilities(server_info, server_metadata) do
    # Extract capabilities from server
    with {:ok, raw_capabilities} <- extract_raw_capabilities(server_info),
         {:ok, normalized_capabilities} <- normalize_capabilities(raw_capabilities),
         {:ok, mapped_capabilities} <- map_to_vsm_taxonomy(normalized_capabilities),
         {:ok, compatibility_matrix} <- build_compatibility_matrix(mapped_capabilities) do
      
      capability_mapping = %{
        server_id: server_info.id,
        raw_capabilities: raw_capabilities,
        normalized_capabilities: normalized_capabilities,
        vsm_mapped_capabilities: mapped_capabilities,
        compatibility_matrix: compatibility_matrix,
        capability_confidence: calculate_capability_confidence(mapped_capabilities),
        integration_complexity: assess_integration_complexity(mapped_capabilities),
        value_assessment: assess_capability_value(mapped_capabilities)
      }
      
      {:ok, capability_mapping}
    end
  end
  
  defp extract_raw_capabilities(server_info) do
    # Connect to server and query capabilities
    case VsmMcp.MCP.Client.list_tools(server_info.client_process) do
      {:ok, tools} ->
        capabilities = Enum.map(tools, fn tool ->
          %{
            type: :tool,
            name: tool.name,
            description: tool.description,
            input_schema: tool.input_schema,
            output_format: infer_output_format(tool),
            complexity: assess_tool_complexity(tool),
            resource_requirements: estimate_resource_requirements(tool)
          }
        end)
        
        # Also get resources and prompts
        resources = case VsmMcp.MCP.Client.list_resources(server_info.client_process) do
          {:ok, res} -> res
          _ -> []
        end
        
        prompts = case VsmMcp.MCP.Client.list_prompts(server_info.client_process) do
          {:ok, prs} -> prs
          _ -> []
        end
        
        all_capabilities = capabilities ++ 
                          map_resources_to_capabilities(resources) ++
                          map_prompts_to_capabilities(prompts)
        
        {:ok, all_capabilities}
        
      {:error, reason} ->
        {:error, "Failed to extract capabilities: #{reason}"}
    end
  end
  
  defp normalize_capabilities(raw_capabilities) do
    # Normalize capability descriptions and parameters
    normalized = Enum.map(raw_capabilities, fn capability ->
      normalized_name = normalize_capability_name(capability.name)
      canonical_description = canonicalize_description(capability.description)
      standardized_parameters = standardize_parameters(capability.input_schema)
      
      %{
        original: capability,
        normalized_name: normalized_name,
        canonical_description: canonical_description,
        standardized_parameters: standardized_parameters,
        capability_category: categorize_capability(capability),
        similarity_fingerprint: generate_similarity_fingerprint(capability)
      }
    end)
    
    {:ok, normalized}
  end
  
  defp map_to_vsm_taxonomy(normalized_capabilities) do
    # Map to VSM system taxonomy
    vsm_taxonomy = %{
      system1_operations: [],
      system2_coordination: [],
      system3_control: [],
      system4_intelligence: [],
      system5_policy: [],
      cross_system: [],
      external_interface: []
    }
    
    mapped_taxonomy = Enum.reduce(normalized_capabilities, vsm_taxonomy, fn capability, acc ->
      vsm_categories = determine_vsm_categories(capability)
      
      Enum.reduce(vsm_categories, acc, fn category, inner_acc ->
        Map.update!(inner_acc, category, &[capability | &1])
      end)
    end)
    
    {:ok, mapped_taxonomy}
  end
  
  defp determine_vsm_categories(capability) do
    categories = []
    
    # System 1: Direct operational capabilities
    categories = if operational_capability?(capability) do
      [:system1_operations | categories]
    else
      categories
    end
    
    # System 2: Coordination and communication
    categories = if coordination_capability?(capability) do
      [:system2_coordination | categories]
    else
      categories
    end
    
    # System 3: Control and monitoring
    categories = if control_capability?(capability) do
      [:system3_control | categories]
    else
      categories
    end
    
    # System 4: Intelligence and scanning
    categories = if intelligence_capability?(capability) do
      [:system4_intelligence | categories]
    else
      categories
    end
    
    # System 5: Policy and decision making
    categories = if policy_capability?(capability) do
      [:system5_policy | categories]
    else
      categories
    end
    
    # Cross-system capabilities
    categories = if cross_system_capability?(capability) do
      [:cross_system | categories]
    else
      categories
    end
    
    # External interface capabilities
    categories = if external_interface_capability?(capability) do
      [:external_interface | categories]
    else
      categories
    end
    
    if categories == [] do
      [:system1_operations]  # Default to System 1
    else
      categories
    end
  end
  
  defp operational_capability?(capability) do
    # Check if capability directly produces value/output
    operational_keywords = [
      "generate", "create", "process", "transform", "convert",
      "analyze", "calculate", "produce", "build", "compile"
    ]
    
    description_lower = String.downcase(capability.canonical_description)
    name_lower = String.downcase(capability.normalized_name)
    
    Enum.any?(operational_keywords, fn keyword ->
      String.contains?(description_lower, keyword) or String.contains?(name_lower, keyword)
    end)
  end
  
  defp intelligence_capability?(capability) do
    # Check if capability involves scanning, analysis, or intelligence gathering
    intelligence_keywords = [
      "scan", "detect", "monitor", "analyze", "research", "discover",
      "investigate", "assess", "evaluate", "inspect", "search"
    ]
    
    description_lower = String.downcase(capability.canonical_description)
    name_lower = String.downcase(capability.normalized_name)
    
    Enum.any?(intelligence_keywords, fn keyword ->
      String.contains?(description_lower, keyword) or String.contains?(name_lower, keyword)
    end)
  end
  
  # ... Additional capability classification functions
end
```

## 5. Lifecycle Management Patterns

### 5.1 Health Monitoring and Auto-Recovery

```elixir
defmodule VsmMcp.Integration.HealthManagement do
  @moduledoc """
  Continuous health monitoring and auto-recovery for integrated MCP servers.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Schedule initial health checks
    Process.send_after(self(), :health_check_cycle, 5_000)
    
    state = %{
      monitored_servers: %{},
      health_history: %{},
      recovery_attempts: %{},
      alert_thresholds: load_alert_thresholds()
    }
    
    {:ok, state}
  end
  
  def handle_info(:health_check_cycle, state) do
    # Perform health checks for all monitored servers
    new_state = perform_health_checks(state)
    
    # Schedule next check cycle
    Process.send_after(self(), :health_check_cycle, 30_000)
    
    {:noreply, new_state}
  end
  
  defp perform_health_checks(state) do
    Enum.reduce(state.monitored_servers, state, fn {server_id, server_info}, acc_state ->
      case check_server_health(server_id, server_info) do
        {:ok, health_metrics} ->
          process_health_metrics(server_id, health_metrics, acc_state)
          
        {:error, reason} ->
          handle_health_check_failure(server_id, reason, acc_state)
      end
    end)
  end
  
  defp check_server_health(server_id, server_info) do
    health_checks = [
      check_connectivity(server_id),
      check_response_time(server_id),
      check_resource_usage(server_id),
      check_error_rate(server_id),
      check_protocol_compliance(server_id)
    ]
    
    # Aggregate health check results
    health_summary = %{
      timestamp: DateTime.utc_now(),
      connectivity: Enum.at(health_checks, 0),
      response_time: Enum.at(health_checks, 1),
      resource_usage: Enum.at(health_checks, 2),
      error_rate: Enum.at(health_checks, 3),
      protocol_compliance: Enum.at(health_checks, 4),
      overall_health: calculate_overall_health(health_checks)
    }
    
    {:ok, health_summary}
  end
  
  defp process_health_metrics(server_id, health_metrics, state) do
    # Update health history
    new_history = Map.update(state.health_history, server_id, [health_metrics], fn history ->
      [health_metrics | Enum.take(history, 99)]  # Keep last 100 entries
    end)
    
    # Check for health deterioration
    state_with_history = %{state | health_history: new_history}
    
    case detect_health_issues(server_id, health_metrics, state_with_history) do
      [] ->
        # Reset recovery attempts on good health
        new_recovery_attempts = Map.delete(state.recovery_attempts, server_id)
        %{state_with_history | recovery_attempts: new_recovery_attempts}
        
      issues ->
        handle_health_issues(server_id, issues, state_with_history)
    end
  end
  
  defp detect_health_issues(server_id, current_metrics, state) do
    issues = []
    thresholds = state.alert_thresholds
    
    # Check response time degradation
    issues = if current_metrics.response_time.avg_ms > thresholds.response_time_critical do
      [:critical_response_time | issues]
    else
      issues
    end
    
    # Check error rate spike
    issues = if current_metrics.error_rate.percentage > thresholds.error_rate_critical do
      [:critical_error_rate | issues]
    else
      issues
    end
    
    # Check resource exhaustion
    issues = if current_metrics.resource_usage.memory_percent > thresholds.memory_critical do
      [:memory_exhaustion | issues]
    else
      issues
    end
    
    # Check connectivity issues
    issues = if current_metrics.connectivity.status != :healthy do
      [:connectivity_issue | issues]
    else
      issues
    end
    
    # Check for trending issues
    trending_issues = detect_trending_issues(server_id, state)
    issues ++ trending_issues
  end
  
  defp handle_health_issues(server_id, issues, state) do
    current_attempts = Map.get(state.recovery_attempts, server_id, 0)
    
    # Determine recovery strategy based on issues and attempt count
    recovery_strategy = determine_recovery_strategy(issues, current_attempts)
    
    case execute_recovery_strategy(server_id, recovery_strategy) do
      :ok ->
        Logger.info("Recovery strategy #{recovery_strategy} successful for server #{server_id}")
        
        # Update recovery attempts
        new_attempts = Map.put(state.recovery_attempts, server_id, current_attempts + 1)
        %{state | recovery_attempts: new_attempts}
        
      {:error, reason} ->
        Logger.error("Recovery strategy #{recovery_strategy} failed for server #{server_id}: #{reason}")
        
        # Try escalated recovery if available
        case escalate_recovery(server_id, recovery_strategy, current_attempts) do
          :ok ->
            new_attempts = Map.put(state.recovery_attempts, server_id, current_attempts + 1)
            %{state | recovery_attempts: new_attempts}
            
          {:error, escalation_reason} ->
            # Final escalation failed - alert and mark server as degraded
            alert_server_failure(server_id, issues, escalation_reason)
            mark_server_degraded(server_id, state)
        end
    end
  end
  
  defp determine_recovery_strategy(issues, attempt_count) do
    cond do
      # First attempt - try gentle recovery
      attempt_count == 0 ->
        if :connectivity_issue in issues do
          :reconnect
        else
          :soft_restart
        end
        
      # Second attempt - more aggressive
      attempt_count == 1 ->
        :hard_restart
        
      # Third attempt - full recovery
      attempt_count == 2 ->
        :full_recovery
        
      # Multiple failures - escalate
      true ->
        :escalate_to_admin
    end
  end
  
  defp execute_recovery_strategy(server_id, strategy) do
    case strategy do
      :reconnect ->
        VsmMcp.MCP.ServerManager.reconnect_server(server_id)
        
      :soft_restart ->
        VsmMcp.MCP.ServerManager.restart_server(server_id, graceful: true)
        
      :hard_restart ->
        VsmMcp.MCP.ServerManager.restart_server(server_id, force: true)
        
      :full_recovery ->
        # Stop, reinstall, and restart
        with :ok <- VsmMcp.MCP.ServerManager.stop_server(server_id),
             {:ok, _} <- reinstall_server(server_id),
             {:ok, _} <- VsmMcp.MCP.ServerManager.start_server(server_id) do
          :ok
        end
        
      :escalate_to_admin ->
        # Send alert to administrators
        send_admin_alert(server_id, "Multiple recovery attempts failed")
        :ok
    end
  end
end
```

This comprehensive external MCP server integration pattern provides a robust framework for discovering, evaluating, installing, testing, and managing external MCP servers within the VSM-MCP autonomous daemon system. The patterns ensure secure, reliable, and scalable integration of external capabilities while maintaining system stability and performance.