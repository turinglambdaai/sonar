#lang racket/base

(require racket/flonum
         rackunit
         sonar)

;; Deterministic stub embedder: each known word maps to a chosen 2-dim
;; vector, so similarity orderings are exact.
(define dictionary
  (hash "cat" (flvector 1.0 0.0)
        "kitten" (flvector 0.9 0.1)
        "dog" (flvector 0.0 1.0)
        "bone" (flvector 0.1 0.9)))

(define stub-batch
  (lambda (texts)
    (for/list ([t (in-list texts)])
      (hash-ref dictionary t
                (lambda ()
                  (error (format "stub embedder does not know ~s" t)))))))

(test-case "store add and count"
  (parameterize ([current-batch-embed stub-batch]
                 [current-embed
                  (lambda (t) (car (stub-batch (list t))))])
    (define s (make-store #:name "pets"))
    (store-add! s "cat" #:source "a.txt")
    (store-add! s "dog" #:source "b.txt")
    (check-equal? (store-count s) 2)
    (check-equal? (entry-text (car (store-entries s))) "dog")
    (check-equal? (store-name s) "pets")))

(test-case "entries are stored normalized"
  (parameterize ([current-batch-embed stub-batch])
    (define s (make-store))
    (define e (store-add! s "kitten"))
    (check-equal? (vector-norm (entry-embedding e)) 1.0)))

(test-case "search ranks by similarity, best first"
  (parameterize ([current-batch-embed stub-batch]
                 [current-embed
                  (lambda (t) (car (stub-batch (list t))))])
    (define s (make-store))
    (store-add! s "cat")
    (store-add! s "dog")
    (store-add! s "bone")
    (define results (store-search s "cat" #:top-k 2))
    (check-equal? (length results) 2)
    (check-equal? (entry-text (cdr (car results))) "cat")
    (check-equal? (car (car results)) 1.0)
    (check-true (> (car (car results)) (car (cadr results))))))

(test-case "top-k larger than the store returns everything"
  (parameterize ([current-batch-embed stub-batch]
                 [current-embed
                  (lambda (t) (car (stub-batch (list t))))])
    (define s (make-store))
    (store-add! s "cat")
    (check-equal? (length (store-search s "dog" #:top-k 10)) 1)))

(test-case "store-add-document! chunks and batches in one call"
  (define calls (box 0))
  (parameterize ([current-batch-embed
                  (lambda (texts)
                    (set-box! calls (add1 (unbox calls)))
                    (for/list ([t (in-list texts)])
                      (flvector (exact->inexact (string-length t)) 1.0)))])
    (define s (make-store))
    (define text
      (apply string-append
             (for/list ([i (in-range 12)])
               (format "Sentence ~a is long enough to split. " i))))
    (define added
      (store-add-document! s text
                           #:source "doc.txt"
                           #:chunk-size 80
                           #:chunk-overlap 10))
    (check-true (> added 1))
    (check-equal? (store-count s) added)
    (check-equal? (unbox calls) 1)
    (for ([e (in-list (store-entries s))])
      (check-equal? (entry-source e) "doc.txt")
      (check-true (< (abs (- (vector-norm (entry-embedding e)) 1.0)) 1e-9)))))

(test-case "an empty document adds nothing"
  (parameterize ([current-batch-embed stub-batch])
    (define s (make-store))
    (check-equal? (store-add-document! s "   ") 0)
    (check-equal? (store-count s) 0)))

(test-case "a degenerate embedder vector names the source in its error"
  (parameterize ([current-batch-embed
                  (lambda (texts) (map (lambda (t) (flvector 0.0 0.0)) texts))])
    (define s (make-store))
    (check-exn exn:fail:sonar?
               (lambda () (store-add! s "cat" #:source "z.txt")))))
