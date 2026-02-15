# RubyGraphRag Non-Technical Overview

## What This Is

`RubyGraphRag` is a tool that helps you understand a Ruby or Rails codebase by turning it into a map.

Think of a codebase like a large city:
- files are buildings,
- classes and methods are rooms,
- calls and render links are roads between rooms.

RubyGraphRag builds that map so you can ask better questions and find answers faster.

## What Problem It Solves

When a software project gets big, it becomes hard to answer simple questions:
- "Where does this feature actually start?"
- "What files are connected to this screen?"
- "If we change this, what else could break?"

RubyGraphRag helps by showing relationships between parts of the code, instead of showing files one by one.

## What You Get

After indexing a repository, you get:
- a structured graph of files and code elements,
- links showing who calls what (`CALLS`),
- links showing inheritance (`INHERITS`),
- links showing template rendering (`RENDERS`) in Rails and ERB.

This gives teams a shared "system map" they can use for onboarding, debugging, planning, and impact analysis.

## New: Smarter Semantic Search

RubyGraphRag now supports two ways to power semantic search:
- `local_hash` mode:
  - fast and dependency-free, good for local/dev usage.
- `openai` mode:
  - model-based embeddings, better meaning-level matching.

In simple terms:
- `local_hash` is like keyword-aware matching.
- `openai` is like intent-aware matching.

This means stakeholders can ask broader questions such as:
- "Where is discount logic similar to this change?"
- "Show code that handles user identity and access."

Even if exact keywords are different, model-based mode can still surface relevant functions.

## How It Works (Plain English)

RubyGraphRag reads your code in passes:
1. It records the folder and file structure.
2. It finds modules, classes, and methods.
3. It records which methods call other methods using an AST parser (Prism), which is more accurate than pattern matching.
4. It applies Rails conventions to infer view rendering links.
5. It scans ERB templates for `render` calls.
6. It saves the result to a backend.

When semantic search is enabled, it also:
7. Converts function code into numeric meaning vectors ("embeddings").
8. Stores those vectors so questions can be matched by intent, not just exact words.

## Backends (Where Data Is Stored)

RubyGraphRag supports two storage options:
- `in_memory`: Fast, temporary, ideal for local experiments.
- `neo4j`: Persistent graph database backend for larger or shared workflows.

For semantic vectors, RubyGraphRag stores them in a Qdrant vector database by default (`semantic_backend = qdrant`), though the `in_memory` backend can be used for quick local experiments or CI runs where persistence is not required.
This is separate from Neo4j and is used for semantic matching.

## Choosing Between Local and Model Modes

Use `local_hash` when:
- you want zero external dependencies,
- you are working offline,
- you need quick local iteration.

Use `openai` when:
- you need better relevance for natural-language questions,
- code uses varied naming that keyword matching misses,
- search quality matters more than API cost/latency.

## What Changes for Non-Technical Users

You can ask higher-level questions and still get useful results, for example:
- "Where is refund eligibility decided?"
- "Show code similar to checkout calculation."
- "What functions look related to profile authorization?"

## Typical Use Cases

- Product and engineering alignment:
  - Understand what areas of the app support a feature.
- Change planning:
  - Estimate impact before modifying code.
- Incident response:
  - Quickly trace dependencies during production issues.
- Team onboarding:
  - Help new developers learn architecture faster.

## What It Is Not

- It is not a replacement for code review.
- It does not automatically prove business correctness.
- It is not a full static analyzer with perfect type-level reasoning.

It is best used as a practical navigation and impact-mapping tool.

## Who Should Use It

- Engineering managers who need system visibility,
- Product managers working closely with technical teams,
- QA leads doing risk-based testing,
- Developers who need to understand unfamiliar code quickly.

## Related Technical Docs

If you want implementation details and command references, use:
- `Gem/README.md`
- `README.md`
