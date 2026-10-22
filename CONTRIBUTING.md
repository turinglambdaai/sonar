# Contributing

## Development loop

```sh
raco pkg install --auto --name sonar .
raco test -p sonar
raco setup --check-pkg-deps sonar
raco scribble --htmls --dest /tmp/sonar-doc sonar-doc/scribblings/sonar.scrbl
racket examples/semantic-search.rkt
```

CI must be green on `main`; whoever pushes a red `main` fixes or reverts on the spot.

## Rules

- Read `AGENTS.md` before changing code; the invariants there are normative.
- Tests inject embedders through `current-batch-embed` — never the network.
- Public API changes land in the same change as their scribble documentation and both READMEs.
