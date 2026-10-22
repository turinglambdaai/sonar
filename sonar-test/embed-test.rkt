#lang racket/base

(require racket/flonum
         rackunit
         sonar)

(define (fl . xs) (for/flvector ([x (in-list xs)]) (exact->inexact x)))

(test-case "no embedder configured fails with a readable error"
  (check-exn exn:fail:sonar?
             (lambda () (embed-texts '("hello")))))

(test-case "embed-texts preserves order"
  (define batch
    (lambda (texts)
      (for/list ([t (in-list texts)])
        (fl (string-length t) 1))))
  (parameterize ([current-batch-embed batch])
    (check-equal? (map (lambda (v) (flvector-ref v 0))
                       (embed-texts '("a" "bbb" "cc")))
                  (list 1.0 3.0 2.0))))

(test-case "repeated texts are embedded once but reported per position"
  (define calls (box 0))
  (define batch
    (lambda (texts)
      (set-box! calls (add1 (unbox calls)))
      (for/list ([t (in-list texts)]) (fl 0 1))))
  (parameterize ([current-batch-embed batch])
    (define result (embed-texts '("x" "y" "x")))
    (check-equal? (length result) 3)
    (check-equal? (unbox calls) 1)))

(test-case "a mismatched embedder response fails loudly"
  (parameterize ([current-batch-embed (lambda (texts) '())])
    (check-exn exn:fail:sonar? (lambda () (embed-texts '("a"))))))

(test-case "current-embed derives from the batch primitive"
  (parameterize ([current-batch-embed
                  (lambda (texts) (map (lambda (t) (fl 1 1)) texts))])
    (check-equal? (vector-norm ((current-embed) "anything"))
                  (flsqrt 2.0))))

(test-case "the cached embedder reuses known text"
  (define calls (box 0))
  (define cached
    (make-cached-batch-embedder
     (lambda (misses)
       (set-box! calls (+ (unbox calls) (length misses)))
       (for/list ([t (in-list misses)]) (fl 1 0)))))
  (cached '("a" "b"))
  (check-equal? (unbox calls) 2)
  (cached '("a" "b" "c"))
  (check-equal? (unbox calls) 3)
  (check-equal? (length (cached '("a" "b" "c"))) 3)
  (check-equal? (unbox calls) 3))
