# MCP Protocol Demo
# Demonstrates the complete MCP implementation with client/server functionality

require Logger

defmodule MCPDemo do
  @moduledoc """
  Demonstrates MCP protocol implementation with VSM integration.
  """

  def run do
    Logger.info("Starting MCP Protocol Demo...")

    # Start MCP server
    {:ok, server} = start_mcp_server()
    
    # Register custom tools
    register_custom_tools(server)
    
    # Start MCP client
    {:ok, client} = start_mcp_client()
    
    # Demonstrate protocol functionality
    demonstrate_tools(client)
    demonstrate_resources(client)
    demonstrate_prompts(client)
    
    Logger.info("MCP Protocol Demo completed!")
  end

  defp start_mcp_server do
    Logger.info("Starting MCP server on TCP port 3333...")
    
    {:ok, server} = VsmMcp.MCP.start_server(
      name: :demo_server,
      transport: :tcp,
      port: 3333,
      auto_start: true
    )

    Logger.info("MCP server started successfully")
    {:ok, server}
  end

  defp register_custom_tools(server) do
    Logger.info("Registering custom MCP tools...")

    # Register variety analysis tool
    VsmMcp.MCP.register_tool(server, "analyze_variety", %{
      description: "Analyze variety in a system using VSM principles",
      input_schema: %{
        type: "object",
        properties: %{
          system_name: %{
            type: "string",
            description: "Name of the system to analyze"
          },
          metrics: %{
            type: "array",
            items: %{type: "string"},
            description: "Metrics to include in analysis"
          }
        },
        required: ["system_name"]
      },
      execute: fn params ->
        # Simulate variety analysis
        analysis = %{
          system: params["system_name"],
          variety_score: :rand.uniform(100),
          complexity: :rand.uniform(10),
          metrics: params["metrics"] || ["default"],
          recommendations: [
            "Increase variety amplification in System 2",
            "Add more feedback loops in System 3",
            "Enhance environmental scanning in System 4"
          ]
        }
        
        {:ok, Jason.encode!(analysis)}
      end
    })

    # Register decision support tool
    VsmMcp.MCP.register_tool(server, "vsm_decision", %{
      description: "Get decision recommendations using VSM System 5",
      input_schema: %{
        type: "object",
        properties: %{
          context: %{
            type: "object",
            description: "Decision context"
          },
          options: %{
            type: "array",
            items: %{type: "string"},
            description: "Available options"
          }
        },
        required: ["context", "options"]
      },
      execute: fn params ->
        # Use VSM System 5 for decision making
        decision = %{
          recommended_option: Enum.random(params["options"]),
          confidence: :rand.uniform() * 0.5 + 0.5,
          rationale: "Based on current system state and environmental factors",
          risks: ["Consider variety imbalance", "Monitor feedback loops"]
        }
        
        {:ok, Jason.encode!(decision)}
      end
    })

    # Register system health resource
    VsmMcp.MCP.register_resource(server, "vsm://health/status", %{
      name: "VSM System Health",
      description: "Current health status of all VSM systems",
      mime_type: "application/json",
      read: fn ->
        health = %{
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          systems: %{
            system1: %{status: "operational", load: 45},
            system2: %{status: "operational", load: 67},
            system3: %{status: "operational", load: 23},
            system4: %{status: "operational", load: 89},
            system5: %{status: "operational", load: 12}
          },
          overall_status: "healthy"
        }
        
        {:ok, Jason.encode!(health)}
      end
    })

    # Register analysis prompt
    VsmMcp.MCP.register_prompt(server, "vsm_analysis", %{
      description: "Generate analysis prompt for VSM systems",
      arguments: [
        %{
          name: "focus_area",
          type: "string",
          description: "Area to focus analysis on"
        }
      ],
      get: fn args ->
        {:ok, [
          %{
            role: "system",
            content: "You are a VSM (Viable System Model) expert analyst."
          },
          %{
            role: "user",
            content: "Analyze the #{args["focus_area"] || "overall system"} using VSM principles. Consider variety, recursion, and system viability."
          }
        ]}
      end
    })

    Logger.info("Custom tools registered")
  end

  defp start_mcp_client do
    Logger.info("Starting MCP client...")
    
    {:ok, client} = VsmMcp.MCP.start_client(
      name: :demo_client,
      transport: :tcp,
      connection: %{host: "localhost", port: 3333},
      auto_connect: false
    )

    # Connect to server
    :ok = VsmMcp.MCP.connect(client)
    
    Logger.info("MCP client connected")
    {:ok, client}
  end

  defp demonstrate_tools(client) do
    Logger.info("\n=== Demonstrating MCP Tools ===")
    
    # List available tools
    {:ok, tools} = VsmMcp.MCP.list_tools(client)
    Logger.info("Available tools: #{inspect(Enum.map(tools, & &1["name"]))}")
    
    # Call variety analysis tool
    Logger.info("\nCalling analyze_variety tool...")
    {:ok, result} = VsmMcp.MCP.call_tool(client, "analyze_variety", %{
      "system_name" => "Production System",
      "metrics" => ["throughput", "quality", "efficiency"]
    })
    
    Logger.info("Variety analysis result:")
    Logger.info(result["content"] |> List.first() |> Map.get("text"))
    
    # Call VSM decision tool
    Logger.info("\nCalling vsm_decision tool...")
    {:ok, result} = VsmMcp.MCP.call_tool(client, "vsm_decision", %{
      "context" => %{
        "situation" => "System overload detected",
        "constraints" => ["budget", "time", "resources"]
      },
      "options" => ["Scale up", "Optimize", "Redistribute load", "Add buffer"]
    })
    
    Logger.info("Decision recommendation:")
    Logger.info(result["content"] |> List.first() |> Map.get("text"))
    
    # Call VSM system tools
    Logger.info("\nCalling VSM system tools...")
    
    # System 1 monitoring
    {:ok, result} = VsmMcp.MCP.call_tool(client, "vsm.system1.monitor", %{
      "metrics" => ["input", "output", "efficiency"]
    })
    Logger.info("System 1 status: #{inspect(result)}")
    
    # System 2 transformation
    {:ok, result} = VsmMcp.MCP.call_tool(client, "vsm.system2.transform", %{
      "input" => %{"complexity" => 100, "variety" => 50},
      "mode" => "attenuate"
    })
    Logger.info("System 2 transformation: #{inspect(result)}")
  end

  defp demonstrate_resources(client) do
    Logger.info("\n=== Demonstrating MCP Resources ===")
    
    # List available resources
    {:ok, resources} = VsmMcp.MCP.list_resources(client)
    Logger.info("Available resources: #{inspect(Enum.map(resources, & &1["uri"]))}")
    
    # Read system health resource
    Logger.info("\nReading VSM system health...")
    {:ok, result} = VsmMcp.MCP.read_resource(client, "vsm://health/status")
    
    content = result["contents"] |> List.first()
    Logger.info("System health:")
    Logger.info(content["text"])
    
    # Subscribe to resource updates
    Logger.info("\nSubscribing to health updates...")
    :ok = VsmMcp.MCP.subscribe_resource(client, "vsm://health/status")
    Logger.info("Subscribed to health updates")
  end

  defp demonstrate_prompts(client) do
    Logger.info("\n=== Demonstrating MCP Prompts ===")
    
    # List available prompts
    {:ok, prompts} = VsmMcp.MCP.list_prompts(client)
    Logger.info("Available prompts: #{inspect(Enum.map(prompts, & &1["name"]))}")
    
    # Get VSM analysis prompt
    Logger.info("\nGetting VSM analysis prompt...")
    {:ok, result} = VsmMcp.MCP.get_prompt(client, "vsm_analysis", %{
      "focus_area" => "variety management"
    })
    
    Logger.info("Generated prompt messages:")
    Enum.each(result["messages"], fn msg ->
      Logger.info("  [#{msg["role"]}]: #{msg["content"]}")
    end)
  end
end

# Run the demo
MCPDemo.run()