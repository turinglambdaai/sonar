#lang scribble/manual

@title{Sonar}
@author{TuringLambdaAI}

Public module: @tt{sonar}

Sonar is in-memory vector search for Racket: chunk text, embed the chunks
through an embedder you control, keep them in a store, and retrieve by
similarity. The pure core never performs I/O against a provider — the
embedding boundary is a parameter, and the Switchboard adapter
(@tt{sonar/switchboard}) is one explicit require away.

Sonar is not a database and not an agent framework. It holds corpora that fit
in memory and answers "which passages resemble this query"; durability beyond
one file is out of scope.

@section{Vectors}

@verbatim{
(vector-dot a b) -> flonum?
(vector-norm v) -> flonum?
(vector-cosine a b) -> flonum?
(vector-normalize v) -> flvector?
  a, b, v : flvector?
}

Dimension mismatches and zero vectors raise: a zero embedding means the
embedder produced garbage upstream, and silently scoring it would corrupt
every ranking. Normalization is idempotent. Entries are normalized once at
add time, so search costs one dot product per entry — no norms are recomputed
per query.

@section{Chunking}

@verbatim{
(chunk-text text #:size size #:overlap overlap) -> (listof string?)
(current-chunk-size) -> exact-positive-integer?   ; default 600
(current-chunk-overlap) -> exact-nonnegative-integer?  ; default 80
}

Chunks break just after the last sentence terminator within a bounded
look-back from the hard cut, otherwise hard-cut. Two invariants hold for any
input: every returned chunk is non-empty, and the scan always advances. Overlap
must be smaller than size.

@section{The embedding boundary}

@verbatim{
(current-batch-embed) -> (-> (listof string?) (listof flvector?))
(current-embed) -> (-> string? flvector?)
(embed-texts texts) -> (listof flvector?)
(make-cached-batch-embedder batch-fn) -> (-> (listof string?) (listof flvector?))
}

The batch function is the primitive: texts in, one vector per text, same
order. Out of the box both parameters raise @tt{exn:fail:sonar} — an
unconfigured embedder must fail loudly, not silently degrade.
@tt{embed-texts} deduplicates and preserves order.
@tt{make-cached-batch-embedder} wraps any batch function with an
exact-string cache, so re-reading a corpus does not re-embed known text.

Installing the Switchboard adapter:

@racketblock[
(require sonar/switchboard)
(current-batch-embed switchboard-batch-embed)
;; knobs:
(current-embed-model "openai/text-embedding-3-small")
(current-embed-dimensions 768) ; #f = model default
]

Change the model only before building or loading a store: saved stores hold
vectors from the old model, and search signals a dimension mismatch.

@section{Stores}

@verbatim{
(make-store #:name name) -> store?
(store-count s) -> exact-nonnegative-integer?
(store-add! s text #:source source) -> entry?
(store-add-document! s text
                     #:source source
                     #:chunk-size size #:chunk-overlap overlap)
 -> exact-nonnegative-integer?
(store-search s query-text #:top-k k)
 -> (listof (cons/c flonum? entry?))
(store-search-vector s query-vector #:top-k k)
 -> (listof (cons/c flonum? entry?))
(entry text source embedding) -> entry?
}

@tt{store-add-document!} chunks the text and embeds all chunks in one batch
call, so a document costs one round trip, not one per chunk. Search scores
are dot products of unit vectors — values in @tt{[-1, 1]} — best first.

@section{Persistence}

@verbatim{
(save-store s path) -> path?
(load-store path) -> store?
}

One s-expression per store. The loader validates shape, rejects foreign
files with @tt{exn:fail:sonar}, and re-normalizes vectors so any store in
memory satisfies the same invariant: unit embeddings, consistent dimension.

@section{Invariants}

@itemlist[
 @item{The pure core performs no provider I/O; the only network boundary is
   the injected embedder parameter.}
 @item{An unconfigured embedder raises. There is no implicit provider.}
 @item{Every embedding entering a store is normalized exactly once, at add
   time.}
 @item{Chunking and store operations make progress on any input; no input
   can loop the scanner.}
]
