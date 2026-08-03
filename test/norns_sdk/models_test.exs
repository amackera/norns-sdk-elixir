defmodule NornsSdk.ModelsTest do
  use ExUnit.Case, async: true

  alias NornsSdk.{AgentResponse, ConversationResponse, EventResponse, RunResponse}

  describe "RunResponse.from_map/1" do
    test "maps id to run_id and carries fields through" do
      run =
        RunResponse.from_map(%{
          "id" => 42,
          "status" => "completed",
          "output" => "done",
          "agent_id" => 7,
          "conversation_id" => 3,
          "trigger_type" => "message",
          "inserted_at" => "2026-01-01T00:00:00Z"
        })

      assert %RunResponse{run_id: 42, status: "completed", output: "done", agent_id: 7} = run
      assert run.conversation_id == 3
    end

    test "defaults trigger_type and tolerates missing optionals" do
      run = RunResponse.from_map(%{"id" => 1, "status" => "running", "agent_id" => 2})
      assert run.trigger_type == "message"
      assert run.output == nil
      assert run.conversation_id == nil
      assert run.waiting_for == nil
      refute RunResponse.waiting?(run)
    end

    test "parses waiting_for on a parked run" do
      run =
        RunResponse.from_map(%{
          "id" => 7,
          "status" => "waiting",
          "agent_id" => 2,
          "waiting_for" => %{
            "question" => "Book the 7pm show?",
            "tool_call_id" => "call_ask",
            "asked_at" => "2026-08-03T00:00:00Z"
          }
        })

      assert RunResponse.waiting?(run)
      assert run.waiting_for.question == "Book the 7pm show?"
      assert run.waiting_for.tool_call_id == "call_ask"
    end
  end

  describe "EventResponse.from_map/1" do
    test "parses an event and defaults payload/source" do
      event = EventResponse.from_map(%{"id" => 1, "sequence" => 0, "event_type" => "llm_response"})
      assert event.event_type == "llm_response"
      assert event.payload == %{}
      assert event.source == ""
    end
  end

  describe "AgentResponse.from_map/1" do
    test "parses an agent with defaults" do
      agent = AgentResponse.from_map(%{"id" => 5, "name" => "bot"})
      assert agent.id == 5
      assert agent.name == "bot"
      assert agent.status == "active"
      assert agent.max_steps == 50
    end
  end

  describe "ConversationResponse.from_map/1" do
    test "parses a conversation with count defaults" do
      convo = ConversationResponse.from_map(%{"id" => 9, "agent_id" => 5, "key" => "slack:U1"})
      assert convo.key == "slack:U1"
      assert convo.message_count == 0
      assert convo.token_estimate == 0
    end
  end
end
