# NornsSdk

[![CI](https://github.com/amackera/norns-sdk-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/amackera/norns-sdk-elixir/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Elixir SDK for [Norns](https://github.com/amackera/norns) — durable agent runtime on BEAM.

Define agents and tools in Elixir, connect to Norns as a worker or interact with agents as a client.

## Install

```elixir
{:norns_sdk, "~> 0.1"}
```

## Worker — define agents and tools

```elixir
defmodule MyTools.SearchDocs do
  use NornsSdk.Tool,
    name: "search_docs",
    description: "Search product documentation"

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{"query" => %{"type" => "string"}},
      "required" => ["query"]
    }
  end

  @impl true
  def execute(%{"query" => query}) do
    results = MyApp.Docs.search(query)
    {:ok, results}
  end
end

agent = NornsSdk.Agent.new(
  name: "support-bot",
  model: "claude-sonnet-4-20250514",
  system_prompt: "You are a customer support agent.",
  tools: [MyTools.SearchDocs],
  mode: :conversation
)

# Add to your supervision tree
children = [
  {NornsSdk.Worker,
   url: "http://localhost:4000",
   api_key: System.get_env("NORNS_API_KEY"),
   llm_api_key: System.get_env("ANTHROPIC_API_KEY"),
   agent: agent}
]
```

The worker connects via WebSocket, registers the agent and tools, and handles LLM + tool tasks from the orchestrator. Reconnects automatically.

## Client — send messages and query results

```elixir
client = NornsSdk.Client.new("http://localhost:4000", api_key: "nrn_...")

# Fire and forget
{:ok, %{run_id: 42}} = NornsSdk.Client.send_message(client, "support-bot", "Hello!")

# Block until completion
{:ok, result} = NornsSdk.Client.send_message(client, "support-bot", "Hello!", wait: true)
IO.puts(result.output)

# With conversation key
{:ok, result} = NornsSdk.Client.send_message(client, "support-bot", "Follow up",
  conversation_key: "slack:U01ABC", wait: true)

# Inspect runs
{:ok, events} = NornsSdk.Client.get_events(client, 42)
```

## License

MIT
