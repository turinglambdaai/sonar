#lang racket/base

;; Optional adapter wiring sonar's embedding boundary to the Switchboard
;; client. Requiring this module changes nothing; installing it is one
;; explicit call, documented in the manual:

;;   (require sonar/switchboard)
;;   (current-batch-embed switchboard-batch-embed)

(require racket/flonum
         switchboard
         "embed.rkt")

(provide switchboard-batch-embed
         current-embed-model
         current-embed-dimensions)

;; Change the model only before building or loading a store: saved stores
;; hold vectors with the old dimension, and search signals a mismatch.
(define current-embed-model (make-parameter "openai/text-embedding-3-small"))

;; #f uses the model's default dimension.
(define current-embed-dimensions (make-parameter #f))

(define (switchboard-batch-embed texts)
  (embed (current-embed-model) texts #:dimensions (current-embed-dimensions)))
