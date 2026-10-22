#lang racket/base

(provide (struct-out exn:fail:sonar)
         raise-sonar)

(struct exn:fail:sonar exn:fail () #:transparent)

(define (raise-sonar message-string)
  (raise (exn:fail:sonar message-string (current-continuation-marks))))
