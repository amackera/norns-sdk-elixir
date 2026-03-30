# Changelog

All notable changes to `norns_sdk` are documented in this file.

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

### Known limitations
- Client streaming is not yet implemented (use `send_message` with `wait: true` and polling).

### Notes
- This is an early v0.1 release focused on core worker/client flows.
- API contracts will continue to harden alongside Norns runtime releases.
