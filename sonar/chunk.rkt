#lang racket/base

;; Text chunking for embedding. Chunks break at sentence boundaries when
;; one is nearby, otherwise hard-cut; every chunk is non-empty and the scan
;; always advances, whatever the text contains.

(require racket/string)

(provide current-chunk-size
         current-chunk-overlap
         chunk-text)

(define current-chunk-size (make-parameter 600))

(define current-chunk-overlap (make-parameter 80))

(define sentence-terminators '(#\. #\! #\? #\newline))

;; How far back from a hard cut to look for a sentence boundary.
(define break-search-radius 80)

(define (chunk-text text
                    #:size [size (current-chunk-size)]
                    #:overlap [overlap (current-chunk-overlap)])
  (unless (exact-positive-integer? size)
    (raise-argument-error 'chunk-text "exact-positive-integer?" size))
  (unless (exact-nonnegative-integer? overlap)
    (raise-argument-error 'chunk-text "exact-nonnegative-integer?" overlap))
  (when (>= overlap size)
    (raise-argument-error 'chunk-text
                          (format "overlap smaller than size ~a" size)
                          overlap))
  (define len (string-length text))
  (let loop ([start 0])
    (if (>= start len)
        '()
        (let* ([hard-end (min (+ start size) len)]
               [break (if (= hard-end len)
                          len
                          (find-break text start hard-end))]
               ;; The scan must advance even when the text fights back.
               [end (max break (add1 start))]
               [chunk (string-trim (substring text start end))]
               [next-start
                (if (>= end len)
                    len
                    (max (- end overlap) (add1 start)))])
          (if (non-empty-string? chunk)
              (cons chunk (loop next-start))
              (loop next-start))))))

;; Position just after the last sentence terminator within the search
;; radius before HARD-END, or HARD-END when none is found.
(define (find-break text start hard-end)
  (define lo (max start (- hard-end break-search-radius)))
  (let loop ([i (sub1 hard-end)])
    (cond
      [(< i lo) hard-end]
      [(memv (string-ref text i) sentence-terminators) (add1 i)]
      [else (loop (sub1 i))])))
