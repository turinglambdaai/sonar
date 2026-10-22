# Changelog

## 0.1.0 — 2026-10-22

- Pure in-memory core: sentence-boundary chunking with guaranteed progress, unit-normalized store entries, dot-product search.
- Embedding boundary as a parameter (`current-batch-embed`); unconfigured use raises. Optional Switchboard adapter (`sonar/switchboard`) with model/dimension knobs.
- `make-cached-batch-embedder` for exact-string embedding caches.
- s-expression store persistence with shape validation and re-normalization on load.
