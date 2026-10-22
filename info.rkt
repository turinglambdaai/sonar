#lang info

(define collection 'multi)
(define deps
  '(["base" #:version "9.0"]
    "switchboard"))
(define build-deps '("rackunit-lib" "racket-doc" "scribble-lib"))
(define pkg-desc "In-memory vector search: chunk, embed, store, and retrieve text")
(define version "0.1")
(define pkg-authors '(turinglambdaai))
(define license 'Apache-2.0)
