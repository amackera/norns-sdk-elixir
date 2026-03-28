defmodule NornsSdk.Client do
  @moduledoc """
  Client for interacting with Norns agents.

  Sends messages, queries runs, manages conversations.

  ## Usage

      client = NornsSdk.Client.new("http://localhost:4000", api_key: "nrn_...")

      # Fire and forget
      {:ok, %{run_id: 42}} = NornsSdk.Client.send_message(client, "support-bot", "Hello!")

      # Block until completion
      {:ok, result} = NornsSdk.Client.send_message(client, "support-bot", "Hello!", wait: true)
      result.output
  """

  defstruct [:base_url, :api_key]

  @type t :: %__MODULE__{base_url: String.t(), api_key: String.t()}

  def new(url, opts \\ []) do
    %__MODULE__{
      base_url: String.trim_trailing(url, "/"),
      api_key: Keyword.get(opts, :api_key, System.get_env("NORNS_API_KEY") || "")
    }
  end

  # --- Agents ---

  def list_agents(%__MODULE__{} = client) do
    case get(client, "/api/v1/agents") do
      {:ok, %{"data" => agents}} -> {:ok, agents}
      error -> error
    end
  end

  def get_agent(%__MODULE__{} = client, id) when is_integer(id) do
    case get(client, "/api/v1/agents/#{id}") do
      {:ok, %{"data" => agent}} -> {:ok, agent}
      error -> error
    end
  end

  def get_agent(%__MODULE__{} = client, name) when is_binary(name) do
    case list_agents(client) do
      {:ok, agents} ->
        case Enum.find(agents, &(&1["name"] == name)) do
          nil -> {:error, :not_found}
          agent -> {:ok, agent}
        end

      error ->
        error
    end
  end

  # --- Messages ---

  def send_message(%__MODULE__{} = client, agent, content, opts \\ []) do
    agent_id = resolve_agent_id(client, agent)
    conversation_key = Keyword.get(opts, :conversation_key)
    wait = Keyword.get(opts, :wait, false)
    timeout = Keyword.get(opts, :timeout, 30_000)

    body =
      %{"content" => content}
      |> maybe_put("conversation_key", conversation_key)

    case post(client, "/api/v1/agents/#{agent_id}/messages", body) do
      {:ok, %{"run_id" => run_id, "status" => status}} ->
        if wait do
          poll_until_complete(client, run_id, timeout)
        else
          {:ok, %{run_id: run_id, status: status, output: nil}}
        end

      error ->
        error
    end
  end

  # --- Runs ---

  def get_run(%__MODULE__{} = client, run_id) do
    case get(client, "/api/v1/runs/#{run_id}") do
      {:ok, %{"data" => run}} -> {:ok, run}
      error -> error
    end
  end

  def get_events(%__MODULE__{} = client, run_id) do
    case get(client, "/api/v1/runs/#{run_id}/events") do
      {:ok, %{"data" => events}} -> {:ok, events}
      error -> error
    end
  end

  # --- Conversations ---

  def list_conversations(%__MODULE__{} = client, agent) do
    agent_id = resolve_agent_id(client, agent)

    case get(client, "/api/v1/agents/#{agent_id}/conversations") do
      {:ok, %{"data" => convos}} -> {:ok, convos}
      error -> error
    end
  end

  def get_conversation(%__MODULE__{} = client, agent, key) do
    agent_id = resolve_agent_id(client, agent)

    case get(client, "/api/v1/agents/#{agent_id}/conversations/#{key}") do
      {:ok, %{"data" => convo}} -> {:ok, convo}
      error -> error
    end
  end

  def delete_conversation(%__MODULE__{} = client, agent, key) do
    agent_id = resolve_agent_id(client, agent)
    delete(client, "/api/v1/agents/#{agent_id}/conversations/#{key}")
  end

  # --- Internal ---

  defp poll_until_complete(client, run_id, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    poll_loop(client, run_id, deadline, 500)
  end

  defp poll_loop(client, run_id, deadline, interval) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, :timeout}
    else
      case get_run(client, run_id) do
        {:ok, %{"status" => status} = run} when status in ["completed", "failed"] ->
          {:ok, %{run_id: run_id, status: status, output: run["output"]}}

        {:ok, _} ->
          Process.sleep(interval)
          next_interval = min(trunc(interval * 1.5), 3_000)
          poll_loop(client, run_id, deadline, next_interval)

        error ->
          error
      end
    end
  end

  defp resolve_agent_id(_client, id) when is_integer(id), do: id

  defp resolve_agent_id(client, name) when is_binary(name) do
    case get_agent(client, name) do
      {:ok, %{"id" => id}} -> id
      _ -> raise "Agent not found: #{name}"
    end
  end

  defp get(client, path) do
    case Req.get(client.base_url <> path, headers: auth_headers(client)) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post(client, path, body) do
    case Req.post(client.base_url <> path, json: body, headers: auth_headers(client)) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete(client, path) do
    case Req.delete(client.base_url <> path, headers: auth_headers(client)) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp auth_headers(client) do
    [{"authorization", "Bearer #{client.api_key}"}]
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
