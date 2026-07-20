defmodule NornsSdk.StreamClient do
  @moduledoc """
  Streams a run's events to a subscriber process over the Norns agent socket.

  You normally start this via `NornsSdk.Client.stream/4` rather than directly.
  It joins the `agent:<id>` channel for a run and forwards each event to the
  subscriber's mailbox as it arrives:

      {:norns_event, stream_pid, %NornsSdk.StreamEvent{type: type, data: data}}

  The two terminal events are `"completed"` and `"error"`; after forwarding one
  of them the process stops normally. If the socket closes before a terminal
  event (disconnect, timeout, join failure), the subscriber receives:

      {:norns_closed, stream_pid, reason}

  so it never blocks forever. The process also stops if the subscriber exits.

  ## Example

      {:ok, _pid} = NornsSdk.Client.stream(client, "support-bot", "Hello!")

      def handle_info({:norns_event, _pid, %{type: "completed"} = ev}, state) do
        IO.puts(ev.data["output"])
        {:noreply, state}
      end
  """

  use Slipstream

  require Logger

  alias NornsSdk.StreamEvent

  @terminal_events ~w(completed error)

  @doc """
  Start streaming events for `run_id` on `agent:<agent_id>`.

  Options:
    * `:base_url` (required) — the Norns HTTP base URL.
    * `:agent_id` (required) — the agent to stream from.
    * `:run_id` (required) — the run to stream.
    * `:subscriber` — pid to deliver events to (defaults to the caller).
    * `:api_key` — bearer token for the socket connection.
  """
  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts)
  end

  @impl Slipstream
  def init(opts) do
    base_url = Keyword.fetch!(opts, :base_url)
    agent_id = Keyword.fetch!(opts, :agent_id)
    run_id = Keyword.fetch!(opts, :run_id)
    subscriber = Keyword.get(opts, :subscriber, self())
    api_key = Keyword.get(opts, :api_key, "")

    # Stop cleanly if the subscriber goes away so we don't leak the socket.
    monitor_ref = Process.monitor(subscriber)

    ws_url =
      base_url
      |> String.trim_trailing("/")
      |> String.replace("http://", "ws://")
      |> String.replace("https://", "wss://")
      |> Kernel.<>("/socket/websocket?token=#{api_key}&vsn=2.0.0")

    state = %{
      topic: "agent:#{agent_id}",
      run_id: run_id,
      subscriber: subscriber,
      monitor_ref: monitor_ref
    }

    {:ok, state, {:connect, ws_url}}
  end

  @impl Slipstream
  def handle_connect(socket) do
    %{topic: topic, run_id: run_id} = socket.assigns
    {:ok, join(socket, topic, %{"run_id" => run_id})}
  end

  @impl Slipstream
  def handle_join(_topic, _reply, socket) do
    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(_topic, event, payload, socket) do
    send(socket.assigns.subscriber, {:norns_event, self(), %StreamEvent{type: event, data: payload}})

    if event in @terminal_events do
      {:stop, :normal, socket}
    else
      {:ok, socket}
    end
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    # Reached only when the socket closes without a terminal event.
    send(socket.assigns.subscriber, {:norns_closed, self(), reason})
    {:stop, :normal, socket}
  end

  @impl Slipstream
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{assigns: %{monitor_ref: ref}} = socket) do
    {:stop, :normal, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
