defmodule NornsSdk.FormatTest do
  use ExUnit.Case, async: true

  alias NornsSdk.Format

  # --- to_anthropic_messages/1 ---

  test "converts simple user message" do
    messages = [%{"role" => "user", "content" => "Hello"}]
    assert Format.to_anthropic_messages(messages) == [%{"role" => "user", "content" => "Hello"}]
  end

  test "converts assistant message with text only" do
    messages = [%{"role" => "assistant", "content" => "Hi there"}]
    assert Format.to_anthropic_messages(messages) == [%{"role" => "assistant", "content" => "Hi there"}]
  end

  test "converts assistant message with tool calls" do
    messages = [
      %{
        "role" => "assistant",
        "content" => "Let me search.",
        "tool_calls" => [
          %{"id" => "tc_1", "name" => "search", "arguments" => %{"query" => "test"}}
        ]
      }
    ]

    [msg] = Format.to_anthropic_messages(messages)
    assert msg["role"] == "assistant"
    assert [text_block, tool_block] = msg["content"]
    assert text_block == %{"type" => "text", "text" => "Let me search."}
    assert tool_block == %{"type" => "tool_use", "id" => "tc_1", "name" => "search", "input" => %{"query" => "test"}}
  end

  test "converts assistant message with tool calls but no text" do
    messages = [
      %{
        "role" => "assistant",
        "content" => "",
        "tool_calls" => [
          %{"id" => "tc_1", "name" => "search", "arguments" => %{"query" => "test"}}
        ]
      }
    ]

    [msg] = Format.to_anthropic_messages(messages)
    assert [tool_block] = msg["content"]
    assert tool_block["type"] == "tool_use"
  end

  test "converts consecutive tool results into single user message" do
    messages = [
      %{"role" => "tool", "tool_call_id" => "tc_1", "name" => "search", "content" => "found it"},
      %{"role" => "tool", "tool_call_id" => "tc_2", "name" => "lookup", "content" => "got it"}
    ]

    [msg] = Format.to_anthropic_messages(messages)
    assert msg["role"] == "user"
    assert [r1, r2] = msg["content"]
    assert r1 == %{"type" => "tool_result", "tool_use_id" => "tc_1", "content" => "found it"}
    assert r2 == %{"type" => "tool_result", "tool_use_id" => "tc_2", "content" => "got it"}
  end

  test "tool result with is_error flag" do
    messages = [
      %{"role" => "tool", "tool_call_id" => "tc_1", "name" => "search", "content" => "boom", "is_error" => true}
    ]

    [msg] = Format.to_anthropic_messages(messages)
    [result] = msg["content"]
    assert result["is_error"] == true
  end

  test "converts full conversation round-trip" do
    messages = [
      %{"role" => "user", "content" => "search for cats"},
      %{
        "role" => "assistant",
        "content" => "",
        "tool_calls" => [%{"id" => "tc_1", "name" => "search", "arguments" => %{"q" => "cats"}}]
      },
      %{"role" => "tool", "tool_call_id" => "tc_1", "name" => "search", "content" => "found cats"},
      %{"role" => "assistant", "content" => "Here are the results."}
    ]

    result = Format.to_anthropic_messages(messages)
    assert length(result) == 4
    assert Enum.at(result, 0)["role"] == "user"
    assert Enum.at(result, 1)["role"] == "assistant"
    assert Enum.at(result, 2)["role"] == "user"
    assert Enum.at(result, 3)["role"] == "assistant"
  end

  # --- to_anthropic_tools/1 ---

  test "converts neutral tool defs to anthropic format" do
    tools = [
      %{"name" => "search", "description" => "Search things", "parameters" => %{"type" => "object"}}
    ]

    [tool] = Format.to_anthropic_tools(tools)
    assert tool["name"] == "search"
    assert tool["description"] == "Search things"
    assert tool["input_schema"] == %{"type" => "object"}
  end

  test "handles input_schema key as fallback" do
    tools = [
      %{"name" => "search", "description" => "Search", "input_schema" => %{"type" => "object"}}
    ]

    [tool] = Format.to_anthropic_tools(tools)
    assert tool["input_schema"] == %{"type" => "object"}
  end

  # --- from_anthropic_response/1 ---

  test "converts text-only response" do
    body = %{
      "content" => [%{"type" => "text", "text" => "Hello!"}],
      "stop_reason" => "end_turn",
      "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
    }

    result = Format.from_anthropic_response(body)
    assert result["status"] == "ok"
    assert result["content"] == "Hello!"
    assert result["finish_reason"] == "stop"
    assert result["usage"] == %{"input_tokens" => 10, "output_tokens" => 5}
    refute Map.has_key?(result, "tool_calls")
  end

  test "converts response with tool use" do
    body = %{
      "content" => [
        %{"type" => "text", "text" => "Let me search."},
        %{"type" => "tool_use", "id" => "tc_1", "name" => "search", "input" => %{"q" => "cats"}}
      ],
      "stop_reason" => "tool_use",
      "usage" => %{"input_tokens" => 20, "output_tokens" => 15}
    }

    result = Format.from_anthropic_response(body)
    assert result["status"] == "ok"
    assert result["content"] == "Let me search."
    assert result["finish_reason"] == "tool_call"
    assert [tc] = result["tool_calls"]
    assert tc["id"] == "tc_1"
    assert tc["name"] == "search"
    assert tc["arguments"] == %{"q" => "cats"}
  end

  test "maps max_tokens to length" do
    body = %{"content" => [], "stop_reason" => "max_tokens", "usage" => %{}}
    assert Format.from_anthropic_response(body)["finish_reason"] == "length"
  end

  test "passes through unknown stop reasons" do
    body = %{"content" => [], "stop_reason" => "something_else", "usage" => %{}}
    assert Format.from_anthropic_response(body)["finish_reason"] == "something_else"
  end

  test "joins multiple text blocks with newline" do
    body = %{
      "content" => [
        %{"type" => "text", "text" => "First."},
        %{"type" => "text", "text" => "Second."}
      ],
      "stop_reason" => "end_turn",
      "usage" => %{}
    }

    assert Format.from_anthropic_response(body)["content"] == "First.\nSecond."
  end
end
