# Domain docs

This repository uses a single-context domain layout.

## Before exploring

Read these files when they exist:

- `CONTEXT.md`
- Relevant records under `docs/adr/`

Missing files are expected. Continue without raising an error. Create them only when the domain-modeling workflow resolves a term or a qualifying architectural decision.

## Layout

```text
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   └── agents/
└── src/
```

## Vocabulary

Use the canonical terms defined in `CONTEXT.md` in code, tests, issues, and documentation. Avoid synonyms explicitly rejected by the glossary.

## Architectural decisions

If proposed work contradicts an existing ADR, identify the conflict instead of silently overriding the recorded decision.
