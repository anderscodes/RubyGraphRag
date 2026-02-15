Feature Comparison: ruby_graph_rag vs graph_code (Python)

Setting aside the language scope (Ruby-only vs. multi-language), these two packages are not equivalent. The Python graph_code package is significantly more feature-rich. Here's the breakdown:

Shared / Equivalent Features
Feature	ruby_graph_rag	graph_code
AST-based code parsing	Prism + regex	Tree-sitter
Knowledge graph construction	Yes	Yes
Graph DB storage	Neo4j (Bolt)	Neo4j (Bolt)
In-memory backend	Yes	No (DB only)
Node types (Project, Folder, File, Module, Class, Method/Function)	Yes	Yes
Relationships (CONTAINS, DEFINES, CALLS, INHERITS)	Yes	Yes
Rails convention detection	Yes	Yes
ERB template parsing	Yes	Yes
Semantic code search (embeddings)	Yes	Yes
Vector store for embeddings	Qdrant (vector DB with in-memory fallback for CI/dev)	Qdrant (vector DB)
CLI interface	Thor-based	Typer-based
MCP tool interface	Yes	Yes
File watching / real-time reindex	Yes	Yes
Cypher query execution	Yes	Yes
Function source retrieval by ID	Yes	Yes
Configurable embedding backends	local_hash / OpenAI	UniXcoder (local)
Top-K similarity search	Yes	Yes
Features Only in graph_code (Python)
Feature	Details
Natural language to Cypher	AI converts English questions into Cypher queries automatically
Dual-model "two-brain" architecture	Separate orchestrator model + specialized Cypher-generation model
7 LLM provider integrations	OpenAI, Anthropic, Google, Ollama, Azure, Cohere, vLLM
Surgical code editing	AST-targeted code replacement with diff previews
Code optimization agent	Language-specific refactoring suggestions with interactive approval
Shell command execution	Safe, allowlisted shell command running from the agent
Document analysis	PDF and image understanding
Graph export to JSON	Full knowledge graph serializable to JSON
Protobuf-based offline indexing	Serialize graph to protobuf for offline storage
Additional node types	Interface, Enum, Type, Union, ExternalPackage, Package
Additional relationships	IMPORTS, EXPORTS, IMPLEMENTS, OVERRIDES, DEPENDS_ON_EXTERNAL
Import/export tracking	Module import and export relationship resolution
Dependency analysis	Parses pyproject.toml, Cargo.toml, etc.
Health check system	doctor command for diagnosing setup issues
Session logging	Timestamped audit trail of interactions
Interactive setup	CLI wizard for configuring exclusions
File creation / writing	Can create and write files through its agent tools
Batched graph ingestion	Configurable batch sizes for performance
Features Only in ruby_graph_rag
Feature	Details
In-memory graph backend	No-database-required mode for quick/dev use
Dual hash-based local embeddings	CRC32-based offline embedding (no ML model needed)
Lightweight / minimal dependencies	No PyTorch, no vector DB server required
Summary
graph_code is a superset. Beyond the language scope difference, the Python package has substantial additional capabilities:

AI agent layer — graph_code includes a full AI agent with natural-language-to-Cypher translation, code editing, optimization, and document analysis. ruby_graph_rag is purely an indexer/retriever with no built-in LLM reasoning.

Richer graph schema — The Python package tracks imports, exports, interfaces, enums, external dependencies, and more relationship types. The Ruby gem has a simpler schema focused on structural containment, calls, inheritance, and renders.

Code modification — graph_code can surgically edit code through its agent. ruby_graph_rag is read-only.

Infrastructure — graph_code uses production-grade tooling (Qdrant for vectors, UniXcoder for embeddings, Neo4j). ruby_graph_rag keeps things lightweight with a configurable Qdrant/in-memory semantic stack and optional local-hash embeddings.

The Ruby gem is best thought of as the indexing and retrieval core of what the Python package offers, without the AI agent, code modification, or richer graph semantics layers.
