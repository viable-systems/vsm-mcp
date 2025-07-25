defmodule VsmMcp.Core.CapabilityMapping do
  @moduledoc """
  Maps generic capability names to real MCP server packages available on NPM.
  This ensures we search for and install actual MCP servers instead of generic terms.
  """

  @doc """
  Maps generic capability names to real MCP server package names.
  Returns a list of actual NPM packages that provide the requested capability.
  """
  def map_capability_to_packages(capability) when is_binary(capability) do
    capability
    |> String.downcase()
    |> do_map_capability()
  end

  def map_capability_to_packages(capability) when is_atom(capability) do
    capability
    |> Atom.to_string()
    |> map_capability_to_packages()
  end

  # Core MCP servers from the official repository
  defp do_map_capability("filesystem") do
    ["@modelcontextprotocol/server-filesystem"]
  end

  defp do_map_capability("github") do
    ["@modelcontextprotocol/server-github"]
  end

  defp do_map_capability("git") do
    ["@modelcontextprotocol/server-git"]
  end

  defp do_map_capability("gitlab") do
    ["@modelcontextprotocol/server-gitlab"]
  end

  defp do_map_capability("google_drive") do
    ["@modelcontextprotocol/server-google-drive"]
  end

  defp do_map_capability("postgres") do
    ["@modelcontextprotocol/server-postgres"]
  end

  defp do_map_capability("sqlite") do
    ["@modelcontextprotocol/server-sqlite", "mcp-server-sqlite"]
  end

  defp do_map_capability("slack") do
    ["@modelcontextprotocol/server-slack"]
  end

  defp do_map_capability("memory") do
    ["@modelcontextprotocol/server-memory"]
  end

  defp do_map_capability("puppeteer") do
    ["@modelcontextprotocol/server-puppeteer"]
  end

  defp do_map_capability("brave_search") do
    ["@modelcontextprotocol/server-brave-search"]
  end

  defp do_map_capability("fetch") do
    ["@modelcontextprotocol/server-fetch"]
  end

  # Generic capability mappings to real MCP servers
  defp do_map_capability("enhanced_processing") do
    [
      "@modelcontextprotocol/server-memory",
      "@modelcontextprotocol/server-filesystem",
      "mcp-server-rust-python"
    ]
  end

  defp do_map_capability("pattern_recognition") do
    [
      "@modelcontextprotocol/server-memory",
      "mcp-server-prometheus",
      "mcp-server-lmstudio"
    ]
  end

  defp do_map_capability("data_transformation") do
    [
      "@modelcontextprotocol/server-sqlite",
      "@modelcontextprotocol/server-postgres",
      "mcp-server-bigquery"
    ]
  end

  defp do_map_capability("parallel_processing") do
    [
      "mcp-server-kubernetes",
      "@modelcontextprotocol/server-memory",
      "mcp-server-docker"
    ]
  end

  defp do_map_capability("optimization") do
    [
      "mcp-server-prometheus",
      "@modelcontextprotocol/server-memory",
      "mcp-server-rust-python"
    ]
  end

  defp do_map_capability("caching") do
    [
      "@modelcontextprotocol/server-memory",
      "mcp-server-redis",
      "@modelcontextprotocol/server-filesystem"
    ]
  end

  defp do_map_capability("efficiency_boost") do
    [
      "@modelcontextprotocol/server-memory",
      "mcp-server-rust-python",
      "@modelcontextprotocol/server-filesystem"
    ]
  end

  defp do_map_capability("resource_management") do
    [
      "mcp-server-kubernetes",
      "mcp-server-docker",
      "@modelcontextprotocol/server-memory"
    ]
  end

  defp do_map_capability("file_operations") do
    [
      "@modelcontextprotocol/server-filesystem",
      "@modelcontextprotocol/server-google-drive",
      "mcp-server-s3"
    ]
  end

  defp do_map_capability("database") do
    [
      "@modelcontextprotocol/server-sqlite",
      "@modelcontextprotocol/server-postgres",
      "mcp-server-mysql",
      "mcp-server-bigquery",
      "mcp-server-clickhouse"
    ]
  end

  defp do_map_capability("api") do
    [
      "@modelcontextprotocol/server-fetch",
      "mcp-server-fastapi",
      "mcp-server-graphql"
    ]
  end

  defp do_map_capability("web") do
    [
      "@modelcontextprotocol/server-puppeteer",
      "@modelcontextprotocol/server-brave-search",
      "@modelcontextprotocol/server-fetch",
      "mcp-server-playwright"
    ]
  end

  defp do_map_capability("search") do
    [
      "@modelcontextprotocol/server-brave-search",
      "mcp-server-elasticsearch",
      "mcp-server-algolia"
    ]
  end

  defp do_map_capability("monitoring") do
    [
      "mcp-server-prometheus",
      "mcp-server-grafana",
      "mcp-server-newrelic"
    ]
  end

  defp do_map_capability("security") do
    [
      "mcp-server-vault",
      "mcp-server-1password",
      "mcp-server-aws-secrets"
    ]
  end

  defp do_map_capability("messaging") do
    [
      "@modelcontextprotocol/server-slack",
      "mcp-server-discord",
      "mcp-server-telegram"
    ]
  end

  defp do_map_capability("cloud") do
    [
      "mcp-server-aws",
      "mcp-server-gcp",
      "mcp-server-azure"
    ]
  end

  defp do_map_capability("containerization") do
    [
      "mcp-server-docker",
      "mcp-server-kubernetes",
      "mcp-server-podman"
    ]
  end

  defp do_map_capability("version_control") do
    [
      "@modelcontextprotocol/server-git",
      "@modelcontextprotocol/server-github",
      "@modelcontextprotocol/server-gitlab"
    ]
  end

  defp do_map_capability("machine_learning") do
    [
      "mcp-server-lmstudio",
      "mcp-server-mlflow",
      "mcp-server-huggingface"
    ]
  end

  # Default fallback - search for generic MCP servers
  defp do_map_capability(_unknown_capability) do
    [
      "@modelcontextprotocol/server-memory",
      "@modelcontextprotocol/server-filesystem",
      "@modelcontextprotocol/server-fetch"
    ]
  end

  @doc """
  Get all known real MCP server packages
  """
  def all_known_packages do
    [
      # Official MCP servers
      "@modelcontextprotocol/server-filesystem",
      "@modelcontextprotocol/server-github",
      "@modelcontextprotocol/server-git",
      "@modelcontextprotocol/server-gitlab",
      "@modelcontextprotocol/server-google-drive",
      "@modelcontextprotocol/server-postgres",
      "@modelcontextprotocol/server-sqlite",
      "@modelcontextprotocol/server-slack",
      "@modelcontextprotocol/server-memory",
      "@modelcontextprotocol/server-puppeteer",
      "@modelcontextprotocol/server-brave-search",
      "@modelcontextprotocol/server-fetch",
      
      # Community MCP servers
      "mcp-server-sqlite",
      "mcp-server-mysql",
      "mcp-server-redis",
      "mcp-server-elasticsearch",
      "mcp-server-prometheus",
      "mcp-server-kubernetes",
      "mcp-server-docker",
      "mcp-server-aws",
      "mcp-server-gcp",
      "mcp-server-azure",
      "mcp-server-s3",
      "mcp-server-bigquery",
      "mcp-server-clickhouse",
      "mcp-server-discord",
      "mcp-server-telegram",
      "mcp-server-fastapi",
      "mcp-server-graphql",
      "mcp-server-playwright",
      "mcp-server-algolia",
      "mcp-server-grafana",
      "mcp-server-newrelic",
      "mcp-server-vault",
      "mcp-server-1password",
      "mcp-server-aws-secrets",
      "mcp-server-podman",
      "mcp-server-mlflow",
      "mcp-server-huggingface",
      "mcp-server-lmstudio",
      "mcp-server-rust-python"
    ]
  end

  @doc """
  Search for real MCP packages based on capability requirements
  """
  def search_real_packages(capabilities) when is_list(capabilities) do
    capabilities
    |> Enum.flat_map(&map_capability_to_packages/1)
    |> Enum.uniq()
  end
end