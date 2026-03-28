defmodule NornsSdk do
  @moduledoc """
  Elixir SDK for the Norns durable agent runtime.

  Two main components:

  - `NornsSdk.Worker` — connects to Norns as a worker, registers agents/tools,
    handles LLM and tool tasks. Add to your supervision tree.
  - `NornsSdk.Client` — sends messages to agents, queries runs, manages conversations.
    Used by web servers, bots, CLI tools.
  """
end
