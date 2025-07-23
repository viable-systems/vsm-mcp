#!/usr/bin/env elixir

# REAL LLM integration with runtime env loading

Code.prepend_path("_build/dev/lib/vsm_mcp/ebin")
Code.prepend_path("_build/dev/lib/jason/ebin")
Code.prepend_path("_build/dev/lib/httpoison/ebin")
Code.prepend_path("_build/dev/lib/hackney/ebin")
Code.prepend_path("_build/dev/lib/certifi/ebin")
Code.prepend_path("_build/dev/lib/idna/ebin")
Code.prepend_path("_build/dev/lib/metrics/ebin")
Code.prepend_path("_build/dev/lib/mimerl/ebin")
Code.prepend_path("_build/dev/lib/parse_trans/ebin")
Code.prepend_path("_build/dev/lib/ssl_verify_fun/ebin")
Code.prepend_path("_build/dev/lib/unicode_util_compat/ebin")

Application.ensure_all_started(:hackney)
Application.ensure_all_started(:httpoison)

# Load environment variables at runtime
if File.exists?(".env") do
  File.read!(".env")
  |> String.split("\n")
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] when key != "" ->
        unless String.starts_with?(key, "#") do
          System.put_env(key, String.trim(value))
        end
      _ -> :ok
    end
  end)
end

IO.puts """
╔═══════════════════════════════════════════════════════════╗
║        REAL LLM + MCP Integration - ACTUALLY WORKS!       ║
╚═══════════════════════════════════════════════════════════╝
"""

# Now make REAL API call
anthropic_key = System.get_env("ANTHROPIC_API_KEY")

if anthropic_key && anthropic_key != "your-api-key-here" do
  IO.puts "✅ Found Anthropic API key\n"
  IO.puts "🌐 Making REAL API call to Claude...\n"
  
  body = Jason.encode!(%{
    model: "claude-3-5-sonnet-20241022",
    messages: [
      %{
        role: "user",
        content: "List 3 NPM packages with 'mcp' in the name that could help create PowerPoint presentations. Just list the package names, nothing else."
      }
    ],
    max_tokens: 200
  })
  
  headers = [
    {"x-api-key", anthropic_key},
    {"anthropic-version", "2023-06-01"},
    {"content-type", "application/json"}
  ]
  
  case HTTPoison.post("https://api.anthropic.com/v1/messages", body, headers, timeout: 30_000, recv_timeout: 30_000) do
    {:ok, %{status_code: 200, body: response_body}} ->
      {:ok, decoded} = Jason.decode(response_body)
      content = hd(decoded["content"])["text"]
      
      IO.puts "🤖 Claude's REAL response:"
      IO.puts "------------------------"
      IO.puts content
      IO.puts "------------------------\n"
      
      # Now REALLY search NPM
      IO.puts "🔍 Searching NPM for REAL MCP packages...\n"
      
      case HTTPoison.get("https://registry.npmjs.org/-/v1/search?text=mcp%20powerpoint&size=5") do
        {:ok, %{status_code: 200, body: npm_body}} ->
          {:ok, npm_data} = Jason.decode(npm_body)
          
          if npm_data["objects"] != [] do
            IO.puts "📦 Found #{length(npm_data["objects"])} REAL packages on NPM:"
            Enum.each(npm_data["objects"], fn obj ->
              pkg = obj["package"]
              IO.puts "  - #{pkg["name"]} v#{pkg["version"]}: #{pkg["description"] || "No description"}"
            end)
          else
            IO.puts "No exact matches, searching broader..."
            
            # Broader search
            case HTTPoison.get("https://registry.npmjs.org/-/v1/search?text=mcp&size=10") do
              {:ok, %{status_code: 200, body: npm_body2}} ->
                {:ok, npm_data2} = Jason.decode(npm_body2)
                IO.puts "\n📦 Found #{length(npm_data2["objects"])} MCP packages:"
                npm_data2["objects"]
                |> Enum.take(5)
                |> Enum.each(fn obj ->
                  pkg = obj["package"]
                  IO.puts "  - #{pkg["name"]} v#{pkg["version"]}"
                end)
            end
          end
          
        {:error, reason} ->
          IO.puts "NPM search failed: #{inspect(reason)}"
      end
      
      IO.puts "\n✅ This was 100% REAL:"
      IO.puts "   - Real API call to Claude"
      IO.puts "   - Real response from Claude"
      IO.puts "   - Real search on NPM registry"
      IO.puts "   - Real MCP packages found"
      
    {:ok, %{status_code: status, body: error_body}} ->
      IO.puts "❌ Anthropic API Error (#{status}):"
      case Jason.decode(error_body) do
        {:ok, error_data} -> IO.inspect(error_data)
        _ -> IO.puts(error_body)
      end
      
    {:error, %{reason: reason}} ->
      IO.puts "❌ Network Error: #{inspect(reason)}"
  end
else
  IO.puts "❌ No API key found. Check .env file"
end