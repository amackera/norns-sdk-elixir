defmodule NornsSdk do
  @moduledoc """
  Elixir SDK for the Norns durable agent runtime.

  Two main components:

  - `NornsSdk.Worker` — connects to Norns as a worker, registers agents/tools,
    handles LLM and tool tasks. Add to your supervision tree.
  - `NornsSdk.Client` — sends messages to agents, queries runs, manages conversations,
    and streams run events (`stream/4`). Used by web servers, bots, CLI tools.

  Client reads return typed structs (`NornsSdk.RunResponse`, `NornsSdk.AgentResponse`,
  `NornsSdk.EventResponse`, `NornsSdk.ConversationResponse`, `NornsSdk.MessageResult`,
  and `NornsSdk.StreamEvent`).
  """
end
