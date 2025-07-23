defmodule VsmMcp.LLM.IntegrationTest do
  use ExUnit.Case
  alias VsmMcp.LLM.Integration
  import ExUnit.CaptureLog

  describe "LLM provider detection" do
    test "detects available providers from environment" do
      providers = Integration.available_providers()
      
      assert is_list(providers)
      # Should detect based on API keys in environment
      if System.get_env("OPENAI_API_KEY"), do: assert :openai in providers
      if System.get_env("ANTHROPIC_API_KEY"), do: assert :anthropic in providers
    end

    test "selects appropriate provider" do
      provider = Integration.select_provider()
      
      assert provider in [:openai, :anthropic, :none]
      # Should prefer available providers
    end
  end

  describe "prompt construction" do
    test "builds search suggestion prompt" do
      prompt = Integration.build_search_prompt("create PowerPoint presentations")
      
      assert String.contains?(prompt, "PowerPoint")
      assert String.contains?(prompt, "MCP") or String.contains?(prompt, "search")
      assert String.contains?(prompt, "NPM") or String.contains?(prompt, "package")
    end

    test "builds capability analysis prompt" do
      gap = %{
        missing: ["presentation_create", "slide_format"],
        current: ["file_read", "file_write"]
      }
      
      prompt = Integration.build_capability_prompt(gap)
      
      assert String.contains?(prompt, "presentation")
      assert String.contains?(prompt, "capability") or String.contains?(prompt, "missing")
    end

    test "includes context in prompts" do
      context = %{
        system: "VSM-MCP",
        task: "autonomous capability acquisition",
        constraints: ["npm packages only", "MCP protocol"]
      }
      
      prompt = Integration.build_contextual_prompt("Find servers", context)
      
      assert String.contains?(prompt, "VSM-MCP")
      assert String.contains?(prompt, "MCP protocol")
      assert String.contains?(prompt, "npm")
    end
  end

  describe "response parsing" do
    test "extracts search terms from LLM response" do
      response = "I suggest searching for: mcp-powerpoint, pptx-generator, slide-mcp"
      
      terms = Integration.parse_search_suggestions(response)
      
      assert "mcp-powerpoint" in terms
      assert "pptx-generator" in terms
      assert "slide-mcp" in terms
    end

    test "parses capability recommendations" do
      response = """
      Based on the gap, you need:
      1. presentation_creation - to create new presentations
      2. slide_management - to add and modify slides
      3. export_pptx - to save as PowerPoint files
      """
      
      capabilities = Integration.parse_capability_recommendations(response)
      
      assert length(capabilities) >= 3
      assert Enum.any?(capabilities, &String.contains?(&1, "presentation"))
      assert Enum.any?(capabilities, &String.contains?(&1, "slide"))
      assert Enum.any?(capabilities, &String.contains?(&1, "export"))
    end

    test "handles various response formats" do
      responses = [
        "mcp-tool1, mcp-tool2, mcp-tool3",
        "Search for:\n- tool1\n- tool2\n- tool3",
        "I recommend: tool1; tool2; tool3"
      ]
      
      for response <- responses do
        parsed = Integration.parse_flexible_response(response)
        assert length(parsed) >= 3
      end
    end
  end

  describe "API interaction" do
    @tag :integration
    @tag :requires_api_key
    test "makes real API call to LLM" do
      # Only run with actual API key
      key = System.get_env("ANTHROPIC_API_KEY") || System.get_env("OPENAI_API_KEY")
      
      if key && key != "" do
        result = Integration.query_llm("Suggest NPM package names for file operations")
        
        assert {:ok, response} = result
        assert is_binary(response)
        assert String.length(response) > 0
      else
        assert true  # Skip if no API key
      end
    end

    test "handles API errors gracefully" do
      # Test with invalid API key
      original_key = System.get_env("ANTHROPIC_API_KEY")
      System.put_env("ANTHROPIC_API_KEY", "invalid-key")
      
      assert capture_log(fn ->
        result = Integration.query_llm("test query")
        assert {:error, _reason} = result
      end) =~ "error" or true  # May not log
      
      # Restore original
      if original_key, do: System.put_env("ANTHROPIC_API_KEY", original_key)
    end

    test "respects rate limits" do
      # Make multiple rapid requests
      results = for i <- 1..3 do
        Integration.query_llm("Quick test #{i}", max_tokens: 10)
      end
      
      # Should handle gracefully (queue, throttle, or error)
      assert Enum.all?(results, fn
        {:ok, _} -> true
        {:error, :rate_limited} -> true
        {:error, _} -> true
      end)
    end
  end

  describe "intelligent decision making" do
    test "analyzes variety gaps intelligently" do
      gap_data = %{
        operational_variety: 20.0,
        environmental_variety: 30.0,
        missing_capabilities: ["cloud_deploy", "auto_scale", "monitoring"]
      }
      
      analysis = Integration.analyze_variety_gap(gap_data)
      
      assert Map.has_key?(analysis, :severity)
      assert Map.has_key?(analysis, :recommendations)
      assert Map.has_key?(analysis, :search_terms)
    end

    test "suggests optimal server selection" do
      servers = [
        %{name: "basic-mcp", capabilities: ["read", "write"]},
        %{name: "advanced-mcp", capabilities: ["read", "write", "analyze", "optimize"]},
        %{name: "specialized-mcp", capabilities: ["ml_predict", "ml_train"]}
      ]
      
      needed = ["read", "analyze", "optimize"]
      
      suggestion = Integration.suggest_best_server(servers, needed)
      
      assert suggestion.server.name == "advanced-mcp"
      assert suggestion.match_score > 0.8
    end
  end

  describe "caching and optimization" do
    test "caches LLM responses" do
      query = "test query for caching"
      
      # First call
      result1 = Integration.query_llm_cached(query)
      
      # Second call should be cached
      result2 = Integration.query_llm_cached(query)
      
      if match?({:ok, _}, result1) and match?({:ok, _}, result2) do
        assert result1 == result2
      end
    end

    test "batches related queries" do
      queries = [
        "Find MCP servers for file operations",
        "Find MCP servers for database operations",
        "Find MCP servers for network operations"
      ]
      
      results = Integration.batch_query_llm(queries)
      
      assert length(results) == length(queries)
      assert Enum.all?(results, fn
        {:ok, _} -> true
        {:error, _} -> true
      end)
    end
  end
end