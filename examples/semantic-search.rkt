#lang racket/base

;; Offline walkthrough: build a small store with a deterministic toy
;; embedder and run two searches. No network, no API key — this is the
;; same run CI performs in the quality job.

(require racket/flonum
         racket/list
         racket/string
         sonar)

;; A toy embedder: hashed word bags into 64 dims, L2-normalized. The char
;; polynomial keeps it deterministic across runs and machines.
(define dims 256)

(define (word->dim word)
  (define h
    (for/fold ([h 5381]) ([ch (in-string word)])
      (remainder (+ (* h 33) (char->integer ch)) 1000003)))
  (remainder h dims))

(define (tokenize text)
  (for/list ([word (in-list (regexp-match* #px"[a-z0-9]+"
                                           (string-downcase text)))])
    ;; plain regular-plural folding so "benchmarks" meets "benchmark"
    (if (and (> (string-length word) 3)
             (string-suffix? "s" word)
             (not (string-suffix? "ss" word)))
        (substring word 0 (sub1 (string-length word)))
        word)))

(define (toy-embed texts)
  (for/list ([text (in-list texts)])
    (define v (make-vector dims 0.0))
    (for ([word (in-list (tokenize text))])
      (vector-set! v (word->dim word)
                   (add1 (vector-ref v (word->dim word)))))
    (define mag (sqrt (for/sum ([x (in-vector v)]) (* x x))))
    (for/flvector ([x (in-vector v)])
      (if (zero? mag) 0.0 (/ x mag)))))

(parameterize ([current-batch-embed toy-embed]
               [current-embed (lambda (text) (car (toy-embed (list text))))])
  (define store (make-store #:name "walkthrough"))

  (store-add-document!
   store
   (string-append
    "The harbor town wakes before dawn. Fishermen mend nets while the market "
    "unloads the night's catch. Gulls circle the docks, and the first ferry "
    "whistle echoes across the water. ")
   #:source "harbor.txt")

  (store-add-document!
   store
   (string-append
    "Compile the project with the release profile before profiling. The "
    "benchmark harness runs each kernel across three dataset sizes and "
    "reports the median runtime of seven repetitions. ")
   #:source "benchmark.txt")

  (for ([query (in-list '("Where do fishermen work?"
                          "How are benchmarks measured?"))])
    (printf "~a\n" query)
    (for ([hit (in-list (store-search store query #:top-k 1))])
      (printf "  [~a] ~a...\n"
              (entry-source (cdr hit))
              (substring (entry-text (cdr hit))
                         0
                         (min 60 (string-length (entry-text (cdr hit)))))))))
