defmodule VsmMcp.Integration.Installer do
  @moduledoc """
  Handles installation of MCP servers from various sources.
  
  Supports:
  - NPM packages
  - Git repositories
  - Local directories
  - Pre-built binaries
  """
  
  require Logger
  
  @installation_dir "priv/mcp_servers"
  @max_retries 3
  @timeout 300_000  # 5 minutes
  
  @doc """
  Installs an MCP server based on its source type.
  """
  def install_server(server_config) do
    installation_path = get_installation_path(server_config)
    
    # Check if already installed
    if File.exists?(installation_path) and not force_reinstall?(server_config) do
      Logger.info("Server already installed at: #{installation_path}")
      {:ok, installation_path}
    else
      perform_installation(server_config, installation_path)
    end
  end
  
  @doc """
  Uninstalls an MCP server.
  """
  def uninstall_server(installation_path) do
    Logger.info("Uninstalling server at: #{installation_path}")
    
    case File.rm_rf(installation_path) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:uninstall_failed, reason}}
    end
  end
  
  @doc """
  Verifies server installation.
  """
  def verify_installation(installation_path) do
    cond do
      not File.exists?(installation_path) ->
        {:error, :not_found}
        
      not has_required_files?(installation_path) ->
        {:error, :incomplete_installation}
        
      true ->
        {:ok, get_installation_info(installation_path)}
    end
  end
  
  ## Private Functions
  
  defp perform_installation(server_config, installation_path) do
    Logger.info("Installing #{server_config.name} to #{installation_path}")
    
    # Ensure installation directory exists
    File.mkdir_p!(Path.dirname(installation_path))
    
    result = case server_config.source_type do
      :npm -> install_from_npm(server_config, installation_path)
      :git -> install_from_git(server_config, installation_path)
      :local -> install_from_local(server_config, installation_path)
      :binary -> install_from_binary(server_config, installation_path)
      _ -> {:error, :unsupported_source_type}
    end
    
    case result do
      :ok ->
        post_install_setup(server_config, installation_path)
        {:ok, installation_path}
        
      error ->
        # Cleanup on failure
        File.rm_rf(installation_path)
        error
    end
  end
  
  defp install_from_npm(server_config, installation_path) do
    package_name = server_config.package_name || server_config.name
    version = server_config.version || "latest"
    
    commands = [
      "mkdir -p #{installation_path}",
      "cd #{installation_path} && npm init -y",
      "cd #{installation_path} && npm install #{package_name}@#{version}"
    ]
    
    execute_installation_commands(commands)
  end
  
  defp install_from_git(server_config, installation_path) do
    repo_url = server_config.repository_url
    branch = server_config.branch || "main"
    
    commands = [
      "git clone --branch #{branch} --depth 1 #{repo_url} #{installation_path}"
    ]
    
    # Add post-clone setup if needed
    if server_config[:requires_build] do
      build_commands = get_build_commands(server_config, installation_path)
      commands = commands ++ build_commands
    end
    
    execute_installation_commands(commands)
  end
  
  defp install_from_local(server_config, installation_path) do
    source_path = server_config.source_path
    
    if File.exists?(source_path) do
      File.cp_r!(source_path, installation_path)
      :ok
    else
      {:error, :source_not_found}
    end
  end
  
  defp install_from_binary(server_config, installation_path) do
    binary_url = server_config.binary_url
    binary_name = Path.basename(binary_url)
    
    commands = [
      "mkdir -p #{installation_path}",
      "cd #{installation_path} && curl -L -o #{binary_name} #{binary_url}",
      "cd #{installation_path} && chmod +x #{binary_name}"
    ]
    
    execute_installation_commands(commands)
  end
  
  defp execute_installation_commands(commands) do
    Enum.reduce_while(commands, :ok, fn command, _acc ->
      Logger.debug("Executing: #{command}")
      
      case System.cmd("bash", ["-c", command], stderr_to_stdout: true) do
        {_output, 0} ->
          {:cont, :ok}
          
        {output, exit_code} ->
          Logger.error("Command failed with exit code #{exit_code}: #{output}")
          {:halt, {:error, {:command_failed, command, exit_code}}}
      end
    end)
  end
  
  defp get_build_commands(server_config, installation_path) do
    build_tool = detect_build_tool(installation_path)
    
    case build_tool do
      :npm ->
        ["cd #{installation_path} && npm install", "cd #{installation_path} && npm run build"]
        
      :yarn ->
        ["cd #{installation_path} && yarn install", "cd #{installation_path} && yarn build"]
        
      :make ->
        ["cd #{installation_path} && make"]
        
      :cargo ->
        ["cd #{installation_path} && cargo build --release"]
        
      _ ->
        # Try generic commands
        ["cd #{installation_path} && npm install || yarn install || true"]
    end
  end
  
  defp detect_build_tool(path) do
    cond do
      File.exists?(Path.join(path, "package.json")) and File.exists?(Path.join(path, "yarn.lock")) ->
        :yarn
        
      File.exists?(Path.join(path, "package.json")) ->
        :npm
        
      File.exists?(Path.join(path, "Makefile")) ->
        :make
        
      File.exists?(Path.join(path, "Cargo.toml")) ->
        :cargo
        
      true ->
        :unknown
    end
  end
  
  defp post_install_setup(server_config, installation_path) do
    # Create wrapper scripts if needed
    if server_config[:create_wrapper] do
      create_wrapper_script(server_config, installation_path)
    end
    
    # Set up configuration
    if server_config[:default_config] do
      write_default_config(server_config, installation_path)
    end
    
    # Install dependencies for MCP protocol
    ensure_mcp_dependencies(installation_path)
  end
  
  defp create_wrapper_script(server_config, installation_path) do
    wrapper_content = """
    #!/bin/bash
    # Auto-generated wrapper for #{server_config.name}
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    #{server_config.start_command || "npm start"}
    """
    
    wrapper_path = Path.join(installation_path, "start.sh")
    File.write!(wrapper_path, wrapper_content)
    File.chmod!(wrapper_path, 0o755)
  end
  
  defp write_default_config(server_config, installation_path) do
    config_path = Path.join(installation_path, "mcp_config.json")
    
    default_config = %{
      name: server_config.name,
      version: server_config.version || "unknown",
      protocol: "mcp",
      transport: server_config.transport || "stdio",
      capabilities: server_config.capabilities || []
    }
    
    File.write!(config_path, Jason.encode!(default_config, pretty: true))
  end
  
  defp ensure_mcp_dependencies(installation_path) do
    # Check if MCP SDK is needed
    package_json_path = Path.join(installation_path, "package.json")
    
    if File.exists?(package_json_path) do
      # Add MCP SDK if not present
      package_json = File.read!(package_json_path) |> Jason.decode!()
      
      unless has_mcp_dependency?(package_json) do
        Logger.info("Adding MCP SDK dependency")
        System.cmd("npm", ["install", "@anthropic/mcp"], cd: installation_path)
      end
    end
  end
  
  defp has_mcp_dependency?(package_json) do
    deps = Map.get(package_json, "dependencies", %{})
    dev_deps = Map.get(package_json, "devDependencies", %{})
    
    Map.has_key?(deps, "@anthropic/mcp") or Map.has_key?(dev_deps, "@anthropic/mcp")
  end
  
  defp get_installation_path(server_config) do
    base_dir = Application.get_env(:vsm_mcp, :mcp_installation_dir, @installation_dir)
    server_dir = "#{server_config.name}_#{server_config.version || "latest"}"
    
    Path.join([base_dir, server_dir])
  end
  
  defp force_reinstall?(server_config) do
    Map.get(server_config, :force_reinstall, false)
  end
  
  defp has_required_files?(installation_path) do
    # Check for common MCP server files
    required_files = [
      "package.json",
      "start.sh",
      "index.js",
      "mcp_config.json"
    ]
    
    Enum.any?(required_files, fn file ->
      File.exists?(Path.join(installation_path, file))
    end)
  end
  
  defp get_installation_info(installation_path) do
    %{
      path: installation_path,
      installed_at: get_installation_time(installation_path),
      size: get_directory_size(installation_path),
      files: get_file_count(installation_path)
    }
  end
  
  defp get_installation_time(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.mtime
      _ -> nil
    end
  end
  
  defp get_directory_size(path) do
    case System.cmd("du", ["-sb", path]) do
      {output, 0} ->
        [size_str | _] = String.split(output, "\t")
        String.to_integer(String.trim(size_str))
        
      _ -> 0
    end
  end
  
  defp get_file_count(path) do
    case System.cmd("find", [path, "-type", "f"], stderr_to_stdout: true) do
      {output, 0} ->
        output |> String.split("\n") |> Enum.reject(&(&1 == "")) |> length()
        
      _ -> 0
    end
  end
end