#lang racket/base

(require racket/file
         racket/flonum
         rackunit
         sonar)

(define stub-batch
  (lambda (texts)
    (for/list ([t (in-list texts)])
      (flvector (exact->inexact (string-length t)) 1.0))))

(test-case "a store survives a save/load round trip"
  (parameterize ([current-batch-embed stub-batch])
    (define s (make-store #:name "roundtrip"))
    (store-add! s "first chunk" #:source "a.txt")
    (store-add! s "second chunk" #:source "b.txt")
    (define path (make-temporary-file "sonar-~a.rktd"))
    (save-store s path)
    (define loaded (load-store path))
    (check-equal? (store-name loaded) "roundtrip")
    (check-equal? (store-count loaded) 2)
    (check-true
     (for/and ([e (in-list (store-entries loaded))])
       (define norm (vector-norm (entry-embedding e)))
       (< (abs (- norm 1.0)) 1e-9)))
    (check-equal?
     (sort (for/list ([e (in-list (store-entries loaded))]) (entry-text e))
           string<?)
     '("first chunk" "second chunk"))
    (check-equal?
     (for/sum ([e (in-list (store-entries loaded))]
               #:when (equal? (entry-source e) "a.txt"))
       1)
     1)))

(test-case "garbage files fail with a readable error"
  (define path (make-temporary-file "sonar-garbage-~a.rktd"))
  (with-output-to-file path (lambda () (write '(not a store))) #:exists 'replace)
  (check-exn exn:fail:sonar? (lambda () (load-store path))))

(test-case "a non-readable file fails with a readable error"
  (define path (make-temporary-file "sonar-binary-~a.rktd"))
  (with-output-to-file path (lambda () (write-bytes #"not sexpr at all")) #:exists 'replace)
  (check-exn exn:fail:sonar? (lambda () (load-store path))))

(test-case "search works identically after a round trip"
  (parameterize ([current-batch-embed stub-batch]
                 [current-embed
                  (lambda (t) (car (stub-batch (list t))))])
    (define s (make-store))
    (store-add! s "first chunk")
    (define path (make-temporary-file "sonar-search-~a.rktd"))
    (save-store s path)
    (define loaded (load-store path))
    (define a (store-search s "first chunk"))
    (define b (store-search-vector
               s (car (stub-batch (list "first chunk"))) #:top-k 5))
    (check-equal? (car (car a)) (car (car b)))))
