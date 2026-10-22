# AGENTS.md

## Scope

Sonar is the in-memory vector retrieval layer of the TuringLambdaAI product
family: chunk, embed, store, and rank text passages. It is not a database, a
disk index, an LLM client, or an agent framework.

## Dependency direction

```text
product -> sonar
sonar/switchboard adapter -> switchboard

sonar core -X-> switchboard
sonar -X-> product
```

The pure core must never require Switchboard or any network client. Only the
`sonar/switchboard` adapter module may.

## Invariants

- The embedding boundary is `current-batch-embed`. The pure core performs no
  provider I/O, and an unconfigured embedder raises `exn:fail:sonar` — there
  is no implicit provider.
- Every embedding entering a store is normalized exactly once, at add time.
  Search is a dot product between unit vectors; scores lie in [-1, 1].
- Zero vectors and dimension mismatches raise. A degenerate vector must
  never silently enter or corrupt a ranking.
- The chunker always advances: every chunk is non-empty and the scan moves
  forward on any input.
- Tests inject embedders through `current-batch-embed`; no test touches the
  network.
- Store files are validated on load; foreign or truncated files raise
  `exn:fail:sonar` instead of loading partial state.
- Public API changes land in the same change as their scribble documentation
  and both READMEs.
