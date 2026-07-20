# Changelog

All notable changes to `norns_sdk` are documented in this file.

## [Unreleased]

### Added
- Typed response structs for all client reads: `NornsSdk.RunResponse`,
  `NornsSdk.EventResponse`, `NornsSdk.AgentResponse`, `NornsSdk.ConversationResponse`,
  `NornsSdk.MessageResult`, and `NornsSdk.StreamEvent`, each with a `from_map/1`
  constructor.
- `NornsSdk.Client.stream/4` — streams a run's events to a subscriber process via
  `NornsSdk.StreamClient` (delivers `{:norns_event, pid, %StreamEvent{}}` messages,
  plus `{:norns_closed, pid, reason}` if the socket closes before a terminal event).

### Changed
- **Breaking:** client read functions now return typed structs instead of raw
  string-keyed maps. `get_run/2`, `get_agent/2`, `list_agents/1`, `get_events/2`,
  `list_conversations/2`, `get_conversation/3`, `create_agent/2`, `update_agent/3`,
  and `send_message/4` return the structs above. Access fields with dot syntax
  (e.g. `run.status`, `agent.id`) rather than `run["status"]`.

### Fixed
- `send_message/4` with `wait: true` now treats `"error"` as a terminal run status
  (alongside `"completed"` and `"failed"`), so failed runs return promptly instead
  of polling until timeout.

## [0.1.0] - 2026-03-29

### Added
- Initial Elixir SDK structure (`NornsSdk.Agent`, `NornsSdk.Tool`, `NornsSdk.Worker`, `NornsSdk.Client`)
- Provider-neutral wire format handling via `NornsSdk.Format`
- Multi-provider LLM support via ReqLLM (Anthropic, OpenAI, Google, Mistral, and more)
- Automatic provider inference from model name (e.g. `"claude-sonnet-4-20250514"` → Anthropic)
- CI pipeline (test, credo, security)
- Integration tests against live Norns server
- Release checklist docs
- README badges and usage examples

### Notes
- This is an early v0.1 release focused on core worker/client flows.
- API contracts will continue to harden alongside Norns runtime releases.
