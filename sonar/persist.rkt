#lang racket/base

;; Corpus persistence as one s-expression per store. Embeddings dominate
;; the file, so a plain write/read round trip beats any richer format; the
;; loader re-validates shape and re-normalizes vectors so files written by
;; any version load into the same invariant.

(require racket/flonum
         racket/list
         racket/match
         "error.rkt"
         "store.rkt"
         "vector.rkt")

(provide save-store
         load-store)

(define format-tag 'sonar-store)
(define format-version 1)

(define (save-store s path)
  (define data
    (list format-tag
          format-version
          (store-name s)
          (for/list ([e (in-list (store-entries s))])
            (list (entry-text e)
                  (entry-source e)
                  (for/list ([x (in-flvector (entry-embedding e))]) x)))))
  (with-output-to-file path
    (lambda () (write data))
    #:exists 'replace)
  path)

(define (load-store path)
  (define data
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (raise-sonar (format "sonar: ~a is not a readable store file" path)))])
      (with-input-from-file path read)))
  (unless (and (list? data)
               (= (length data) 4)
               (eq? (car data) format-tag)
               (exact-positive-integer? (cadr data))
               (<= (cadr data) format-version)
               (string? (caddr data))
               (and (list? (cadddr data)) (andmap entry-data? (cadddr data))))
    (raise-sonar (format "sonar: ~a is not a valid sonar store file" path)))
  (store (caddr data)
         (for/list ([entry-json (in-list (cadddr data))])
           (match-define (list text source embedding-data) entry-json)
           (entry text
                  source
                  (vector-normalize
                   (for/flvector ([x (in-list embedding-data)])
                     (exact->inexact x)))))))

(define (entry-data? v)
  (and (list? v)
       (= (length v) 3)
       (string? (car v))
       (let ([source (cadr v)])
         (or (string? source) (not source)))
       (let ([embedding (caddr v)])
         (and (list? embedding)
              (pair? embedding)
              (andmap real? embedding)))))
