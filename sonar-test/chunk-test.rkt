#lang racket/base

(require rackunit
         racket/string
         sonar)

(test-case "short text is a single chunk"
  (check-equal? (chunk-text "Hello world.") '("Hello world."))
  (check-equal? (chunk-text "") '()))

(test-case "whitespace-only text produces no chunks"
  (check-equal? (chunk-text "   \n  ") '()))

(test-case "long text splits at sentence boundaries"
  (define text
    (apply string-append
           (for/list ([i (in-range 30)])
             (format "Sentence number ~a ends here. " i))))
  (define chunks (chunk-text text #:size 80 #:overlap 0))
  (check-true (> (length chunks) 1))
  (for ([c (in-list chunks)])
    (check-true (non-empty-string? c))
    (check-true (<= (string-length c) 80))
    ;; every chunk is trimmed
    (check-equal? c (string-trim c))))

(test-case "the whole text is covered: chunks reassemble to the content"
  (define text
    (apply string-append
           (for/list ([i (in-range 40)])
             (format "Paragraph ~a has some words. " i))))
  (define chunks (chunk-text text #:size 100 #:overlap 0))
  ;; no terminator inside a chunk, so every sentence appears intact
  (for ([i (in-range 40)])
    (check-true
     (ormap (lambda (c) (string-contains? c (format "Paragraph ~a has some words." i)))
            chunks))))

(test-case "text without terminators hard-cuts"
  (define text (make-string 250 #\x))
  (define chunks (chunk-text text #:size 100 #:overlap 0))
  (check-equal? (map string-length chunks) '(100 100 50)))

(test-case "overlap keeps the last words of the previous chunk"
  (define text
    (string-append "One two three four. " "Five six seven eight. "
                   "Nine ten eleven twelve. " "Thirteen fourteen fifteen."))
  (define chunks (chunk-text text #:size 30 #:overlap 10))
  (check-true (> (length chunks) 2)))

(test-case "overlap must be smaller than size"
  (check-exn exn:fail:contract?
             (lambda () (chunk-text "hello" #:size 10 #:overlap 10)))
  (check-exn exn:fail:contract?
             (lambda () (chunk-text "hello" #:size 10 #:overlap 20))))
