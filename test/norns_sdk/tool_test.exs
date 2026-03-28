defmodule NornsSdk.ToolTest do
  use ExUnit.Case, async: true

  defmodule EchoTool do
    use NornsSdk.Tool,
      name: "echo",
      description: "Echo back the input",
      side_effect: false

    @impl true
    def input_schema do
      %{
        "type" => "object",
        "properties" => %{
          "message" => %{"type" => "string"}
        },
        "required" => ["message"]
      }
    end

    @impl true
    def execute(%{"message" => msg}) do
      {:ok, "echo: #{msg}"}
    end
  end

  defmodule DangerousTool do
    use NornsSdk.Tool,
      name: "dangerous",
      description: "Does something risky",
      side_effect: true

    @impl true
    def input_schema, do: %{"type" => "object", "properties" => %{}}

    @impl true
    def execute(_input), do: {:ok, "done"}
  end

  test "tool module implements callbacks" do
    assert EchoTool.__tool_name__() == "echo"
    assert EchoTool.__tool_description__() == "Echo back the input"
    assert EchoTool.__tool_side_effect__() == false
  end

  test "tool execute works" do
    assert {:ok, "echo: hello"} = EchoTool.execute(%{"message" => "hello"})
  end

  test "to_registration produces wire format" do
    reg = EchoTool.to_registration()
    assert reg["name"] == "echo"
    assert reg["description"] == "Echo back the input"
    assert reg["side_effect"] == false
    assert is_map(reg["input_schema"])
  end

  test "side_effect flag" do
    assert DangerousTool.__tool_side_effect__() == true
    assert DangerousTool.to_registration()["side_effect"] == true
  end
end
