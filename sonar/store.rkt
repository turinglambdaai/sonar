#lang racket/base

;; The store. Entries are embedded and normalized at add time, so search is
;; a dot product per entry and nothing else. The pure core only ever talks
;; to current-batch-embed / current-embed — never to a provider.

(require racket/flonum
         racket/list
         "chunk.rkt"
         "embed.rkt"
         "error.rkt"
         "vector.rkt")

(provide (struct-out entry)
         (struct-out store)
         make-store
         store-count
         store-add!
         store-add-document!
         store-search
         store-search-vector)

(struct entry (text source embedding) #:transparent)

;; entries is a (listof entry?); the field is mutable because a store is
;; an accumulator. Queries are read-only.
(struct store (name [entries #:mutable]) #:transparent)

(define (make-store #:name [name "default"])
  (store name '()))

(define (store-count s)
  (length (store-entries s)))

;; Adds one text as one entry; returns the entry.
(define (store-add! s text #:source [source #f])
  (define vector ((current-embed) text))
  (define e (entry text source (embed-vector->unit vector source)))
  (set-store-entries! s (cons e (store-entries s)))
  e)

;; Chunks TEXT, embeds all chunks in one batch, and adds them as entries.
;; Returns the number of entries added.
(define (store-add-document! s text
                             #:source [source #f]
                             #:chunk-size [chunk-size (current-chunk-size)]
                             #:chunk-overlap [chunk-overlap (current-chunk-overlap)])
  (define chunks (chunk-text text #:size chunk-size #:overlap chunk-overlap))
  (cond
    [(null? chunks) 0]
    [else
     (define vectors ((current-batch-embed) chunks))
     (unless (= (length vectors) (length chunks))
       (raise-sonar
        (format "sonar: embedder returned ~a vectors for ~a chunks"
                (length vectors) (length chunks))))
     (define new-entries
       (for/list ([chunk (in-list chunks)]
                  [vector (in-list vectors)])
         (entry chunk source (embed-vector->unit vector source))))
     (set-store-entries! s (append (reverse new-entries) (store-entries s)))
     (length new-entries)]))

;; Ranks entries by similarity to QUERY-TEXT; returns up to TOP-K
;; (score . entry) pairs, best first. Scores are dot products of unit
;; vectors, so they lie in [-1, 1].
(define (store-search s query-text #:top-k [top-k 5])
  (define query ((current-embed) query-text))
  (store-search-vector s query #:top-k top-k))

(define (store-search-vector s query-vector #:top-k [top-k 5])
  (unless (flvector? query-vector)
    (raise-argument-error 'store-search-vector "flvector?" query-vector))
  (unless (exact-positive-integer? top-k)
    (raise-argument-error 'store-search "exact-positive-integer?" top-k))
  (define query (embed-vector->unit query-vector #f))
  (define ranked
    (sort (for/list ([e (in-list (store-entries s))])
            (cons (vector-dot query (entry-embedding e)) e))
          >
          #:key car))
  (take ranked (min top-k (length ranked))))

;; Every vector entering a store is normalized once, here.
(define (embed-vector->unit vector source)
  (unless (flvector? vector)
    (raise-sonar
     (format "sonar: embedder returned ~s instead of an flvector~a"
             vector
             (if source (format " (source: ~a)" source) ""))))
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (raise-sonar
         (format "sonar: zero-magnitude embedding~a; the embedder produced a degenerate vector"
                 (if source (format " for source ~a" source) ""))))])
    (vector-normalize vector)))
