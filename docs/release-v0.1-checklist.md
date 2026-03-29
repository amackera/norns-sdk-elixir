# norns-sdk-elixir v0.1 Release Checklist

## 1) Package + versioning
- [ ] Confirm `mix.exs` version + metadata
- [ ] Add/refresh `CHANGELOG.md`
- [ ] Tag `v0.1.0`

## 2) Contract alignment
- [ ] Verify worker join payload vs Norns current protocol
- [ ] Verify client send/poll/event APIs vs Norns response shapes

## 3) Tests
- [ ] `mix test` passes
- [ ] Add integration test against local Norns runtime

## 4) Docs
- [ ] README examples compile and run
- [ ] Include minimal worker + client quickstart with expected output

## 5) Release
- [ ] Publish Hex package (if desired)
- [ ] Create GitHub release notes with known limitations
