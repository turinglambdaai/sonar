#lang racket/base

(require racket/flonum
         rackunit
         sonar)

(define (fl . xs) (for/flvector ([x (in-list xs)]) (exact->inexact x)))

(test-case "dot, norm, and cosine agree on textbook values"
  (check-equal? (vector-dot (fl 1 2 3) (fl 4 5 6)) 32.0)
  (check-equal? (vector-norm (fl 3 4)) 5.0)
  (check-equal? (vector-cosine (fl 1 0) (fl 1 0)) 1.0)
  (check-equal? (vector-cosine (fl 1 0) (fl 0 1)) 0.0)
  (check-equal? (vector-cosine (fl 1 0) (fl -1 0)) -1.0))

(test-case "dimension mismatches are loud"
  (check-exn exn:fail? (lambda () (vector-dot (fl 1 2) (fl 1 2 3)))))

(test-case "zero vectors have no direction and are rejected"
  (check-exn exn:fail? (lambda () (vector-normalize (fl 0 0))))
  (check-exn exn:fail? (lambda () (vector-cosine (fl 0 0) (fl 1 1)))))

(test-case "normalization is unit length and idempotent"
  (define v (vector-normalize (fl 3 4)))
  (check-equal? (vector-norm v) 1.0)
  (check-equal? (vector-dot v (fl 1 0)) 0.6)
  (check-equal? (vector-normalize v) v))
