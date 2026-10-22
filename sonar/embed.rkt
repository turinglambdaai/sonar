#lang racket/base

;; The embedding boundary. The pure core never touches the network: callers
;; either inject a batch embedder directly or install the Switchboard
;; adapter (sonar/switchboard). Tests always inject.

(require racket/list
         "error.rkt")

(provide current-batch-embed
         current-embed
         embed-texts
         make-cached-batch-embedder)

;; (current-batch-embed) : (-> (listof string?) (listof flvector?))
;; The batch function is the primitive; it receives texts in order and must
;; return one vector per text, same order.
(define (no-embedder-configured texts)
  (raise-sonar
   "sonar: no embedder configured; require sonar/switchboard and set (current-batch-embed switchboard-batch-embed), or parameterize current-batch-embed"))
(define current-batch-embed (make-parameter no-embedder-configured))

;; Single-text convenience derived from the batch primitive.
(define current-embed
  (make-parameter
   (lambda (text)
     (car ((current-batch-embed) (list text))))))

;; Embeds TEXTS preserving order, deduplicating repeated strings first.
(define (embed-texts texts)
  (unless (and (list? texts) (andmap string? texts))
    (raise-argument-error 'embed-texts "(listof string?)" texts))
  (define unique (remove-duplicates texts))
  (define vectors ((current-batch-embed) unique))
  (unless (= (length vectors) (length unique))
    (raise-sonar
     (format "sonar: embedder returned ~a vectors for ~a texts"
             (length vectors) (length unique))))
  (define by-text (for/hash ([t (in-list unique)] [v (in-list vectors)]) (values t v)))
  (for/list ([t (in-list texts)]) (hash-ref by-text t)))

;; Wraps a batch function with an exact-string cache so rebuilding or
;; re-searching a corpus does not re-embed known text.
(define (make-cached-batch-embedder batch-fn)
  (define cache (make-hash))
  (lambda (texts)
    (define unique (remove-duplicates texts))
    (define misses
      (for/list ([t (in-list unique)]
                 #:unless (hash-has-key? cache t))
        t))
    (unless (null? misses)
      (define vectors (batch-fn misses))
      (unless (= (length vectors) (length misses))
        (raise-sonar
         (format "sonar: embedder returned ~a vectors for ~a texts"
                 (length vectors) (length misses))))
      (for ([t (in-list misses)] [v (in-list vectors)])
        (hash-set! cache t v)))
    (for/list ([t (in-list texts)]) (hash-ref cache t))))
