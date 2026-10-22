# Sonar

**In-memory vector search for Racket — chunk, embed, store, retrieve.**

[![CI](https://github.com/turinglambdaai/sonar/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/sonar/actions/workflows/ci.yml) ![Racket](https://img.shields.io/badge/Racket-9F1D20?logo=racket&logoColor=white) [![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**English** · [中文](README.zh-CN.md)

Sonar keeps a corpus of embedded text passages in memory and answers one question well: *which passages resemble this query?* Text is chunked at sentence boundaries, embedded through an embedder you control, normalized once at add time, and searched with a plain dot product. The pure core never touches the network — the embedding boundary is a parameter, and the [Switchboard](https://github.com/turinglambdaai/switchboard) adapter is one explicit require away.

Sonar is not a database, a disk index, or an agent framework. It owns the piece in the middle that everything else got wrong in ad-hoc scripts: deterministic chunking, loud failures, and one store invariant — every embedding is a unit vector.

## Quick start

```racket
(require sonar)

;; 1. Pick an embedder. The core raises until you configure one.
(require sonar/switchboard)
(current-batch-embed switchboard-batch-embed)

;; 2. Build a store.
(define store (make-store #:name "notes"))
(store-add-document!
 store
 (file->string "notes/climate.txt")
 #:source "climate.txt")

;; 3. Search.
(for ([hit (in-list (store-search store "how fast do glaciers move?"))])
  (printf "~a  ~a...\n"
          (entry-source (cdr hit))
          (substring (entry-text (cdr hit)) 0 60)))
```

An offline run needs no provider at all — inject any batch embedder:

```racket
(parameterize ([current-batch-embed my-embedder])
  (store-search store "query"))
```

A runnable walkthrough lives in `examples/semantic-search.rkt` and runs in CI with a deterministic toy embedder.

## Design notes

- **The embedding boundary is a parameter.** `current-batch-embed` is the only way vectors enter a store. An unconfigured embedder raises — there is no implicit provider, so a missing setup step cannot silently hollow out your search quality.
- **Normalize once.** Every embedding is normalized at add time; search is one dot product per entry, and scores are comparable cosine values in `[-1, 1]`.
- **Progress guaranteed.** The chunker breaks at sentence boundaries when one is nearby, hard-cuts otherwise, and provably advances on any input — pathological text cannot loop it.
- **Loud failures.** Dimension mismatches, zero vectors, malformed store files, and embedders that return the wrong count all raise `exn:fail:sonar` with the cause named.
- **Embedding caching is a wrapper, not a behavior.** `make-cached-batch-embedder` wraps any batch function, so re-reading a corpus never re-pays for known text.

## Development

```sh
raco pkg install --auto --name sonar .
raco test -p sonar
raco setup --check-pkg-deps sonar
racket examples/semantic-search.rkt
```

CI runs the test suite on Linux, Windows, and macOS against Racket 9.0 and 9.3, then checks declared dependencies, builds the reference manual, and runs the offline walkthrough.

## License

[Apache-2.0](LICENSE)
