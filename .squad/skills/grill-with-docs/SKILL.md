---
name: grill-with-docs
description: Stress-test a plan or design against the project's domain language. Sharpens terminology, updates CONTEXT.md glossary, and creates ADRs for hard-to-reverse decisions.
confidence: low
source: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs
---

# Grill With Docs

Interview relentlessly about every aspect of a plan until shared understanding is reached. Walk each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask questions one at a time, waiting for feedback before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Domain Awareness

### CONTEXT.md — Domain Glossary

A single `CONTEXT.md` lives at the repo root. It is a glossary, not a spec. No implementation details.

**Format:**

```md
# {Project Name}

{One or two sentence description of what this project is.}

## Language

**Term**:
{A concise description — one sentence max. Define what it IS, not what it does.}
_Avoid_: synonym1, synonym2

## Relationships

- A **Route** connects exactly one origin **Planet** to one destination **Planet**
- A **Ship** is assigned to exactly one **Route** at a time

## Example Dialogue

> **Dev:** "When a player creates a **Route**, does the **Ship** start flying immediately?"
> **Domain expert:** "No — the **Ship** begins operating the **Route** next turn."

## Flagged Ambiguities

- "route" was used to mean both the path and the scheduled service — resolved: Route is the scheduled service.
```

**Rules:**
- Be opinionated — pick the best term, list others as _Avoid_
- Flag conflicts explicitly
- Keep definitions tight — one sentence
- Show relationships with bold term names
- Only include terms specific to this project's domain
- Create CONTEXT.md lazily — only when the first term is resolved

### ADRs — Architecture Decision Records

ADRs live in `docs/adr/` using sequential numbering: `0001-slug.md`.

**Only create an ADR when ALL THREE are true:**
1. Hard to reverse — changing your mind later is costly
2. Surprising without context — a future reader will wonder why
3. Result of a real trade-off — genuine alternatives existed

**Format:**

```md
# {Short title}

{1-3 sentences: context, decision, and why.}
```

Most ADRs are a single paragraph. The value is recording *that* a decision was made and *why*.

## During a Grilling Session

1. **Challenge against the glossary** — when a term conflicts with CONTEXT.md, call it out immediately
2. **Sharpen fuzzy language** — propose precise canonical terms for vague or overloaded words
3. **Discuss concrete scenarios** — stress-test with edge cases that force precision
4. **Cross-reference with code** — if code contradicts a claim, surface it
5. **Update CONTEXT.md inline** — capture resolved terms as they happen, don't batch
6. **Offer ADRs sparingly** — only when all three criteria above are met

## Adaptation Notes

This skill was adapted from mattpocock/skills for use in a game project. The enterprise DDD scaffolding (CONTEXT-MAP.md, multi-context repos) was removed as unnecessary for this project's scope. ADRs complement but don't replace Squad's decisions.md — use ADRs for architectural decisions that benefit from the "why" narrative, and decisions.md for operational/scope decisions.
