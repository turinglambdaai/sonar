#lang racket/base

;; Vector arithmetic on flvectors. All entries in a store are normalized at
;; add time, so search is a plain dot product and the norm is never
;; recomputed per query.

(require racket/flonum)

(provide vector-dot
         vector-norm
         vector-cosine
         vector-normalize)

(define (checked-pair who a b)
  (unless (= (flvector-length a) (flvector-length b))
    (raise-argument-error who
                          (format "flvector of length ~a (dimension mismatch)"
                                  (flvector-length a))
                          b)))

(define (vector-dot a b)
  (checked-pair 'vector-dot a b)
  (for/sum ([x (in-flvector a)] [y (in-flvector b)]) (fl* x y)))

(define (vector-norm v)
  (flsqrt (for/sum ([x (in-flvector v)]) (fl* x x))))

(define (vector-cosine a b)
  (checked-pair 'vector-cosine a b)
  (define mag-a (vector-norm a))
  (define mag-b (vector-norm b))
  (when (or (fl= mag-a 0.0) (fl= mag-b 0.0))
    (raise-argument-error 'vector-cosine "non-zero flvector" (if (fl= mag-a 0.0) a b)))
  (fl/ (vector-dot a b) (fl* mag-a mag-b)))

;; Unit-length copy. A zero vector has no direction: raise, because it
;; signals a broken embedder upstream. Already-unit vectors pass through,
;; so normalization is idempotent.
(define (vector-normalize v)
  (define mag (vector-norm v))
  (when (fl= mag 0.0)
    (raise-argument-error 'vector-normalize "non-zero flvector" v))
  (if (< (flabs (fl- mag 1.0)) 1e-12)
      v
      (for/flvector ([x (in-flvector v)]) (fl/ x mag))))
