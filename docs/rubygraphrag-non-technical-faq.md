# RubyGraphRag Non-Technical FAQ and Glossary

## FAQ

### What does RubyGraphRag actually do?

It reads Ruby/Rails code and builds a relationship map so teams can understand what connects to what.

### Does this change my application code?

No. It analyzes code and stores graph data. It does not automatically rewrite your app.

### Do I need to know Ruby to benefit from it?

No. Non-technical users can still use summaries and dependency maps to guide planning and risk discussions.

### Is this only for developers?

No. Product, QA, and engineering leadership can all use the outputs to align scope and reduce risk.

### Is the graph always 100% complete?

No static analysis tool is perfect. RubyGraphRag is very useful for structure and dependency discovery, but engineering validation is still required.

### Has call matching quality improved recently?

Yes. RubyGraphRag now uses AST-based parsing (Prism) for call extraction instead of relying on simple text matching, which improves readability and accuracy.

### What is the main value for project delivery?

Better visibility and fewer surprises:
- faster impact analysis,
- clearer ownership,
- more focused testing.

### Can this help with Rails view flow understanding?

Yes. It includes Rails and ERB render relationship extraction so teams can trace many controller-to-view paths.

### What is new in semantic search?

RubyGraphRag now supports model-based semantic embeddings (`openai` mode) in addition to local dependency-free embeddings (`local_hash` mode).

### What is the difference between `local_hash` and `openai` modes?

- `local_hash`:
  - no external AI service required,
  - fastest to set up,
  - lower meaning-level accuracy.
- `openai`:
  - uses an embedding model API,
  - better matching for intent and concept-level similarity,
  - requires API key and has API cost/latency.

### Should non-technical teams care which mode is used?

Yes. It affects search quality and confidence:
- use `openai` for planning, discovery, and risk analysis where quality matters,
- use `local_hash` for quick local checks and low-stakes exploration.

### Does model-based search expose source code externally?

It can, depending on deployment and configuration, because code text is sent to the configured embedding API endpoint.
Teams should align with security/privacy policy before using `openai` mode.

## Glossary (Plain Language)

- Graph:
  - A map of connected items.
- Node:
  - A thing in the map (for example a file, class, or method).
- Relationship/Edge:
  - A connection between two things (for example "calls" or "renders").
- `CALLS`:
  - Method A invokes Method B.
- `INHERITS`:
  - One class extends another class.
- `RENDERS`:
  - A controller/template renders a view or partial.
- Indexing:
  - The process of scanning a repository and building the graph.
- Backend:
  - Where graph data is stored (`in_memory` or `neo4j`).
- Neo4j:
  - A graph database used for persistent storage and querying.
- ERB:
  - Embedded Ruby templates used in Rails views.
- Embedding:
  - A numeric representation of code meaning used for similarity search.
- Semantic Search:
  - Searching by intent/meaning, not exact words.
- `local_hash`:
  - Local embedding method with no external model dependency.
- `openai`:
  - Model-based embedding backend through an OpenAI-compatible API.

## Recommended Collaboration Pattern

For best outcomes:
1. Non-technical stakeholder defines the business question.
2. Engineer runs indexing/query and shares a concise map.
3. Team decides scope, risk, and test plan from the same evidence.

This keeps planning and implementation aligned.
