defmodule NornsSdk.RunResponse do
  @moduledoc """
  A run's details, as returned by `GET /api/v1/runs/:id`.
  """

  defstruct [
    :run_id,
    :status,
    :output,
    :agent_id,
    :conversation_id,
    :trigger_type,
    :waiting_for,
    :inserted_at
  ]

  @type t :: %__MODULE__{
          run_id: integer(),
          status: String.t(),
          output: String.t() | nil,
          agent_id: integer(),
          conversation_id: integer() | nil,
          trigger_type: String.t(),
          waiting_for: NornsSdk.WaitingFor.t() | nil,
          inserted_at: String.t() | nil
        }

  @doc "Parse a decoded API map (string keys) into a `RunResponse`."
  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    %__MODULE__{
      run_id: data["id"],
      status: data["status"],
      output: data["output"],
      agent_id: data["agent_id"],
      conversation_id: data["conversation_id"],
      trigger_type: Map.get(data, "trigger_type", "message"),
      waiting_for: NornsSdk.WaitingFor.from_map(data["waiting_for"]),
      inserted_at: data["inserted_at"]
    }
  end

  @doc "Whether the run is parked on an `ask_human` question."
  @spec waiting?(t()) :: boolean()
  def waiting?(%__MODULE__{status: "waiting"}), do: true
  def waiting?(%__MODULE__{}), do: false
end

defmodule NornsSdk.WaitingFor do
  @moduledoc """
  The question a run is parked on, present when its status is `"waiting"`.

  Answer it with `NornsSdk.Client.reply/3`, or by sending the agent a normal
  message — a message to a parked agent is treated as the answer.
  """

  defstruct [:question, :tool_call_id, :asked_at]

  @type t :: %__MODULE__{
          question: String.t(),
          tool_call_id: String.t(),
          asked_at: String.t() | nil
        }

  @doc "Parse the `waiting_for` object from a run payload. `nil` passes through."
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(data) when is_map(data) do
    %__MODULE__{
      question: data["question"],
      tool_call_id: data["tool_call_id"],
      asked_at: data["asked_at"]
    }
  end
end

defmodule NornsSdk.EventResponse do
  @moduledoc """
  A single event from a run's event log, as returned by
  `GET /api/v1/runs/:id/events`.
  """

  defstruct [:id, :sequence, :event_type, :payload, :source, :inserted_at]

  @type t :: %__MODULE__{
          id: integer(),
          sequence: integer(),
          event_type: String.t(),
          payload: map(),
          source: String.t(),
          inserted_at: String.t() | nil
        }

  @doc "Parse a decoded API map (string keys) into an `EventResponse`."
  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      sequence: data["sequence"],
      event_type: data["event_type"],
      payload: Map.get(data, "payload", %{}),
      source: Map.get(data, "source", ""),
      inserted_at: data["inserted_at"]
    }
  end
end

defmodule NornsSdk.AgentResponse do
  @moduledoc """
  An agent's server-side details, as returned by the agents API.

  Distinct from `NornsSdk.Agent`, which is the declarative definition you
  register from a worker.
  """

  defstruct [:id, :name, :status, :model, :mode, :system_prompt, :max_steps]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          status: String.t(),
          model: String.t(),
          mode: String.t(),
          system_prompt: String.t(),
          max_steps: integer()
        }

  @doc "Parse a decoded API map (string keys) into an `AgentResponse`."
  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      status: Map.get(data, "status", "active"),
      model: Map.get(data, "model", ""),
      mode: Map.get(data, "mode", "task"),
      system_prompt: Map.get(data, "system_prompt", ""),
      max_steps: Map.get(data, "max_steps", 50)
    }
  end
end

defmodule NornsSdk.ConversationResponse do
  @moduledoc """
  A conversation's details, as returned by the conversations API.
  """

  defstruct [:id, :agent_id, :key, :message_count, :token_estimate]

  @type t :: %__MODULE__{
          id: integer(),
          agent_id: integer(),
          key: String.t(),
          message_count: integer(),
          token_estimate: integer()
        }

  @doc "Parse a decoded API map (string keys) into a `ConversationResponse`."
  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      agent_id: data["agent_id"],
      key: data["key"],
      message_count: Map.get(data, "message_count", 0),
      token_estimate: Map.get(data, "token_estimate", 0)
    }
  end
end

defmodule NornsSdk.MessageResult do
  @moduledoc """
  The result of `NornsSdk.Client.send_message/4`.

  When called without `wait: true`, `status` is the accepted status and
  `output` is `nil`. With `wait: true`, they reflect the run state that ended
  the wait.

  A run can stop on `"waiting"` — the agent asked the human a question and is
  parked. `waiting_for` carries the question; answer it with
  `NornsSdk.Client.reply/3` or by sending another message.
  """

  defstruct [:run_id, :status, :output, :conversation_key, :waiting_for]

  @type t :: %__MODULE__{
          run_id: integer(),
          status: String.t(),
          output: String.t() | nil,
          conversation_key: String.t() | nil,
          waiting_for: NornsSdk.WaitingFor.t() | nil
        }

  @doc "Whether the agent is parked on a question rather than finished."
  @spec waiting?(t()) :: boolean()
  def waiting?(%__MODULE__{status: "waiting"}), do: true
  def waiting?(%__MODULE__{}), do: false
end

defmodule NornsSdk.StreamEvent do
  @moduledoc """
  A single event delivered to a subscriber by `NornsSdk.Client.stream/4`.

  `type` is the event name broadcast by the agent (e.g. `"llm_response"`,
  `"tool_call"`, `"tool_result"`, `"completed"`, `"error"`) and `data` is the
  event payload.
  """

  defstruct [:type, :data]

  @type t :: %__MODULE__{type: String.t(), data: map()}
end
