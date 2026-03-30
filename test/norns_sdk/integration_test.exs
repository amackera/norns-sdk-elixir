defmodule NornsSdk.IntegrationTest do
  @moduledoc """
  Integration tests against a live Norns server.

  Requires env vars:
    NORNS_URL         — e.g. http://localhost:4001
    NORNS_API_KEY     — tenant API key
    ANTHROPIC_API_KEY — for LLM calls in worker tests

  Run with:
    mix test --include integration
  """
  use ExUnit.Case

  alias NornsSdk.{Agent, Client, Worker}

  @moduletag :integration

  @norns_url System.get_env("NORNS_URL")
  @norns_api_key System.get_env("NORNS_API_KEY")
  @anthropic_api_key System.get_env("ANTHROPIC_API_KEY")

  setup do
    if @norns_url && @norns_api_key do
      %{client: Client.new(@norns_url, api_key: @norns_api_key)}
    else
      flunk("NORNS_URL and NORNS_API_KEY must be set to run integration tests")
    end
  end

  defp unique_name(prefix) do
    hex = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{prefix}-#{hex}"
  end

  defp create_agent(name, opts \\ []) do
    Agent.new(
      name: name,
      model: "claude-sonnet-4-20250514",
      system_prompt: Keyword.get(opts, :system_prompt, "You are a test agent. Reply concisely."),
      tools: Keyword.get(opts, :tools, [])
    )
  end

  defp ensure_agent_exists(agent) do
    c = Client.new(@norns_url, api_key: @norns_api_key)

    case Client.get_agent(c, agent.name) do
      {:ok, _} ->
        :ok

      {:error, :not_found} ->
        body = %{
          "name" => agent.name,
          "system_prompt" => agent.system_prompt,
          "status" => "idle",
          "model" => agent.model,
          "max_steps" => agent.max_steps,
          "model_config" => %{
            "mode" => to_string(agent.mode),
            "checkpoint_policy" => to_string(agent.checkpoint_policy),
            "context_strategy" => to_string(agent.context_strategy),
            "context_window" => agent.context_window,
            "on_failure" => to_string(agent.on_failure)
          }
        }

        Req.post!("#{@norns_url}/api/v1/agents",
          json: body,
          headers: [{"authorization", "Bearer #{@norns_api_key}"}]
        )
    end
  end

  defp start_worker(agent) do
    Worker.start_link(
      url: @norns_url,
      api_key: @norns_api_key,
      llm_api_key: @anthropic_api_key,
      agent: agent,
      name: :"worker_#{System.unique_integer([:positive])}"
    )
  end

  # --- Agent Management ---

  test "list agents", %{client: c} do
    {:ok, agents} = Client.list_agents(c)
    assert is_list(agents)
  end

  test "create and get agent by name", %{client: c} do
    name = unique_name("test-agent")
    agent = create_agent(name)
    ensure_agent_exists(agent)

    {:ok, found} = Client.get_agent(c, name)
    assert found["name"] == name
  end

  test "get agent not found", %{client: c} do
    assert {:error, :not_found} = Client.get_agent(c, "nonexistent-#{System.os_time()}")
  end

  # --- Full round-trip: worker + client ---

  defmodule EchoTool do
    use NornsSdk.Tool,
      name: "echo",
      description: "Echo back the input text exactly"

    @impl true
    def input_schema do
      %{
        "type" => "object",
        "properties" => %{"text" => %{"type" => "string"}},
        "required" => ["text"]
      }
    end

    @impl true
    def execute(%{"text" => text}), do: {:ok, text}
  end

  @tag :llm
  test "send message and complete via worker", %{client: c} do
    unless @anthropic_api_key do
      flunk("ANTHROPIC_API_KEY must be set for LLM tests")
    end

    name = unique_name("test-roundtrip")

    agent =
      create_agent(name,
        tools: [EchoTool],
        system_prompt:
          "You are a test agent. Use the echo tool with the user's exact message, then reply with what it returned."
      )

    ensure_agent_exists(agent)
    {:ok, _pid} = start_worker(agent)

    # Let the worker connect and register
    Process.sleep(2_000)

    {:ok, %{"id" => agent_id}} = Client.get_agent(c, name)

    # Send message and wait for completion
    {:ok, result} = Client.send_message(c, agent_id, "hello", wait: true, timeout: 60_000)
    assert result.status == "completed"
    assert result.output != nil
    assert byte_size(result.output) > 0

    # Verify run details
    {:ok, run} = Client.get_run(c, result.run_id)
    assert run["id"] == result.run_id
    assert run["status"] == "completed"

    # Verify events were logged
    {:ok, events} = Client.get_events(c, result.run_id)
    assert is_list(events)
    assert length(events) > 0
    event_types = MapSet.new(events, & &1["event_type"])
    assert "llm_response" in event_types
  end

  # --- Conversations ---

  test "list conversations", %{client: c} do
    case Client.list_agents(c) do
      {:ok, [agent | _]} ->
        {:ok, convos} = Client.list_conversations(c, agent["id"])
        assert is_list(convos)

      {:ok, []} ->
        IO.puts("Skipping: no agents registered on server")
    end
  end
end
