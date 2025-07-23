defmodule VsmMcp.Integration.CapabilityMatcherTest do
  use ExUnit.Case
  alias VsmMcp.Integration.CapabilityMatcher

  describe "capability matching" do
    test "matches exact capabilities" do
      required = ["file_read", "file_write", "json_parse"]
      available = ["file_read", "file_write", "json_parse", "http_client"]
      
      result = CapabilityMatcher.match(required, available)
      
      assert result.match_score == 1.0
      assert result.matched == required
      assert result.missing == []
      assert result.extra == ["http_client"]
    end

    test "identifies missing capabilities" do
      required = ["file_read", "file_write", "database_query"]
      available = ["file_read", "http_client"]
      
      result = CapabilityMatcher.match(required, available)
      
      assert result.match_score < 1.0
      assert result.matched == ["file_read"]
      assert result.missing == ["file_write", "database_query"]
    end

    test "scores partial matches" do
      required = ["powerpoint_create", "powerpoint_edit", "powerpoint_export"]
      available = ["pptx_generate", "presentation_create", "pdf_export"]
      
      result = CapabilityMatcher.fuzzy_match(required, available)
      
      assert result.match_score > 0.5  # Partial match
      assert length(result.similar_pairs) > 0
    end

    test "ranks multiple servers by capability match" do
      required = ["document_create", "document_export", "template_use"]
      
      servers = [
        %{name: "server1", capabilities: ["document_create", "pdf_export"]},
        %{name: "server2", capabilities: ["document_create", "document_export", "template_use"]},
        %{name: "server3", capabilities: ["file_read", "file_write"]}
      ]
      
      ranked = CapabilityMatcher.rank_servers(servers, required)
      
      assert hd(ranked).name == "server2"  # Perfect match
      assert List.last(ranked).name == "server3"  # Poor match
    end
  end

  describe "capability analysis" do
    test "analyzes capability overlap" do
      server1_caps = ["read", "write", "parse", "analyze"]
      server2_caps = ["write", "parse", "transform", "export"]
      
      overlap = CapabilityMatcher.analyze_overlap(server1_caps, server2_caps)
      
      assert overlap.common == ["write", "parse"]
      assert overlap.unique_to_first == ["read", "analyze"]
      assert overlap.unique_to_second == ["transform", "export"]
      assert overlap.overlap_ratio == 0.5  # 2 common out of 4
    end

    test "suggests complementary servers" do
      current_capabilities = ["file_read", "json_parse"]
      required_capabilities = ["file_read", "json_parse", "database_write", "cache_manage"]
      
      available_servers = [
        %{name: "db_server", capabilities: ["database_read", "database_write"]},
        %{name: "cache_server", capabilities: ["cache_read", "cache_write", "cache_manage"]},
        %{name: "file_server", capabilities: ["file_read", "file_write"]}
      ]
      
      suggestions = CapabilityMatcher.suggest_complementary(
        current_capabilities,
        required_capabilities,
        available_servers
      )
      
      assert length(suggestions) == 2
      assert Enum.any?(suggestions, & &1.name == "db_server")
      assert Enum.any?(suggestions, & &1.name == "cache_server")
    end
  end

  describe "capability inference" do
    test "infers capabilities from description" do
      description = "A PowerPoint MCP server that creates, edits, and exports presentations"
      
      inferred = CapabilityMatcher.infer_capabilities(description)
      
      assert "presentation_create" in inferred or "create" in inferred
      assert "presentation_edit" in inferred or "edit" in inferred
      assert "presentation_export" in inferred or "export" in inferred
    end

    test "maps common capability synonyms" do
      capabilities = ["make_file", "remove_file", "change_file"]
      
      normalized = CapabilityMatcher.normalize_capabilities(capabilities)
      
      assert "file_create" in normalized or "create_file" in normalized
      assert "file_delete" in normalized or "delete_file" in normalized
      assert "file_update" in normalized or "update_file" in normalized
    end
  end

  describe "capability composition" do
    test "composes complex capabilities from simple ones" do
      available = ["file_read", "file_write", "json_parse", "json_generate"]
      
      composable = CapabilityMatcher.find_composable(available, "json_transform")
      
      assert composable.possible == true
      assert "json_parse" in composable.required_capabilities
      assert "json_generate" in composable.required_capabilities
    end

    test "identifies capability chains" do
      target = "pdf_from_markdown"
      available_servers = [
        %{name: "md_parser", capabilities: ["markdown_parse", "html_generate"]},
        %{name: "html_pdf", capabilities: ["html_parse", "pdf_generate"]},
        %{name: "direct_md_pdf", capabilities: ["markdown_to_pdf"]}
      ]
      
      chains = CapabilityMatcher.find_capability_chains(target, available_servers)
      
      # Should find both direct and chained solutions
      assert length(chains) >= 1
      assert Enum.any?(chains, & length(&1) == 1)  # Direct solution
      assert Enum.any?(chains, & length(&1) == 2)  # Chained solution
    end
  end
end