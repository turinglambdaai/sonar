#lang info

(define collection 'multi)
(define deps
  '(["base" #:version "9.0"]
    "switchboard"
    "rackunit-lib"))
(define build-deps '("racket-doc" "scribble-lib"))
(define pkg-desc "In-memory vector search: chunk, embed, store, and retrieve text")
(define version "0.1")
(define pkg-authors '(turinglambdaai))
(define license 'Apache-2.0)
