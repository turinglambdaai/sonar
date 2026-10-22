#lang racket/base

;; Smoke test for the Switchboard adapter. It verifies wiring only — no
;; network call happens without an explicit invocation.

(require rackunit
         sonar
         sonar/switchboard)

(test-case "the adapter exposes model knobs and a batch embedder"
  (check-equal? (current-embed-model) "openai/text-embedding-3-small")
  (check-false (current-embed-dimensions))
  (check-true (procedure? switchboard-batch-embed)))

(test-case "the adapter respects its own knobs"
  (parameterize ([current-embed-model "gemini/gemini-embedding-001"]
                 [current-embed-dimensions 768])
    ;; Installing the adapter is explicit; here we only assert that the
    ;; parameters round-trip and that the core stays untouched.
    (check-equal? (current-embed-model) "gemini/gemini-embedding-001")
    (check-equal? (current-embed-dimensions) 768)))

(test-case "the pure core stays unconfigured by the adapter require"
  (check-exn exn:fail:sonar? (lambda () (embed-texts '("hello")))))
