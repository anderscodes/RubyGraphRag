# RubyGraphRag Gem: Change Summary

This document summarizes the major changes made to create and evolve the Ruby gem implementation in this repository.

## 1. Gem Creation and Naming

- Created a standalone Ruby gem under `Gem/`.
- Renamed gem identity to `RubyGraphRag`:
  - module: `RubyGraphRag`
  - gemspec: `Gem/ruby_graph_rag.gemspec`
  - primary library path: `Gem/lib/ruby_graph_rag/`
  - entry file: `Gem/lib/ruby_graph_rag.rb`

## 2. Core Indexing Pipeline

Implemented `RubyGraphRag::GraphUpdater` in:
- `Gem/lib/ruby_graph_rag/graph_updater.rb`

Pipeline behavior includes:
1. project/folder/file structure indexing
2. Ruby definitions extraction (modules/classes/methods/functions)
3. call relationship extraction (`CALLS`)
4. Rails convention render inference (`RENDERS`)
5. ERB render extraction (`RENDERS`)
6. graph flush to backend
7. semantic embedding pass for indexed method sources

## 3. Ruby, Rails, and ERB Parsers

Implemented parser processors in:
- `Gem/lib/ruby_graph_rag/parsers/structure_processor.rb`
- `Gem/lib/ruby_graph_rag/parsers/definition_processor.rb`
- `Gem/lib/ruby_graph_rag/parsers/call_processor.rb`
- `Gem/lib/ruby_graph_rag/parsers/rails_convention_processor.rb`
- `Gem/lib/ruby_graph_rag/parsers/erb_processor.rb`
- `Gem/lib/ruby_graph_rag/parsers/processor_factory.rb`

Notable changes:
- Added Ruby class/module/method extraction and inheritance detection.
- Added Rails implicit and explicit render resolution.
- Added ERB embedded Ruby render extraction.
- Upgraded call parsing from regex-style extraction to AST-based extraction using `Prism`.

## 4. Call Resolution Improvements

Enhanced `CALLS` resolution in:
- `Gem/lib/ruby_graph_rag/parsers/call_processor.rb`

Current behavior:
- receiver-aware resolution (`self`, locals, ivars, constants)
- lightweight local/ivar type inference from `Class.new`
- ambiguity reduction with owner-scoped preference and ranking
- AST-driven call/render analysis using `Prism`

Limit:
- still heuristic (not full whole-program type-flow analysis)

## 5. Ingestors and Storage Backends

Implemented backend services:
- in-memory backend:
  - `Gem/lib/ruby_graph_rag/services/in_memory_ingestor.rb`
- Neo4j/Bolt backend:
  - `Gem/lib/ruby_graph_rag/services/neo4j_bolt_ingestor.rb`
- ingestor interface:
  - `Gem/lib/ruby_graph_rag/services/ingestor.rb`

## 6. CLI and Realtime

Implemented CLI:
- `Gem/lib/ruby_graph_rag/cli.rb`
- executable: `Gem/exe/ruby-graph-rag`

Available commands:
- `index`
- `query`
- `watch`
- `semantic_search`
- `get_function_source`

Implemented file watch/reindex loop:
- `Gem/lib/ruby_graph_rag/realtime/watcher.rb`

## 7. MCP-Style Tool Endpoints

Implemented local MCP-style dispatcher:
- `Gem/lib/ruby_graph_rag/mcp/tool_endpoints.rb`

Supported tool methods:
- `index_repository`
- `list_directory`
- `read_file`
- `query_code_graph`
- `semantic_code_search`
- `get_function_source`

## 8. Embedding and Semantic Search Stack

Added full semantic stack in Ruby gem:
- embedder:
  - `Gem/lib/ruby_graph_rag/embedder.rb`
- vector store:
  - `Gem/lib/ruby_graph_rag/vector_store.rb`
  - default backend: `Gem/lib/ruby_graph_rag/vector_backends/qdrant_backend.rb` (Qdrant for production, `VectorBackends::InMemoryBackend` fallback for fast local runs)
- semantic tools:
  - `Gem/lib/ruby_graph_rag/tools/semantic_search.rb`

Backends for embeddings:
- `local_hash` (dependency-free local mode)
- `openai` (model-based embeddings via OpenAI-compatible `/embeddings` API)

Config options in:
- `Gem/lib/ruby_graph_rag/config.rb`

Includes:
- embedding backend selection
- model and API endpoint/key settings
- vector dimensions/top-k/store path settings

## 9. Dependencies Added/Updated

Gemspec updates in:
- `Gem/ruby_graph_rag.gemspec`

Added/used dependencies include:
- `dry-configurable`
- `listen`
- `thor`
- `neo4j-ruby-driver`
- `ruby_tree_sitter`
- `prism`
- test/dev: `rspec`, `simplecov`, `rake`

## 10. Test Suite Additions and Updates

Added/expanded tests in:
- `Gem/spec/ruby_graph_rag/call_processor_spec.rb`
- `Gem/spec/ruby_graph_rag/definition_processor_spec.rb`
- `Gem/spec/ruby_graph_rag/erb_processor_spec.rb`
- `Gem/spec/ruby_graph_rag/rails_convention_processor_spec.rb`
- `Gem/spec/ruby_graph_rag/rails_render_resolution_spec.rb`
- `Gem/spec/ruby_graph_rag/graph_updater_spec.rb`
- `Gem/spec/ruby_graph_rag/mcp_tool_endpoints_spec.rb`
- `Gem/spec/ruby_graph_rag/cli_spec.rb`
- `Gem/spec/ruby_graph_rag/semantic_search_spec.rb`
- `Gem/spec/ruby_graph_rag/embedder_spec.rb`
- `Gem/spec/ruby_graph_rag/vector_store_spec.rb`
- `Gem/spec/ruby_graph_rag/neo4j_bolt_ingestor_spec.rb`
- `Gem/spec/ruby_graph_rag/realtime_watcher_spec.rb`

Test harness updates:
- `Gem/spec/spec_helper.rb`
  - isolated semantic vector store path per test
  - config reset between examples

## 11. Documentation Updates

Updated technical documentation:
- `Gem/README.md`
  - full gem overview
  - architecture and pipeline
  - CLI usage including semantic commands
  - MCP examples
  - embedding modes (`local_hash`/`openai`)
  - updated parser/call-resolution notes

Updated non-technical docs:
- `Gem/docs/rubygraphrag-non-technical-index.md`
- `Gem/docs/rubygraphrag-non-technical-overview.md`
- `Gem/docs/rubygraphrag-non-technical-playbook.md`
- `Gem/docs/rubygraphrag-non-technical-faq.md`

These include:
- plain-language explanation of semantic embeddings
- guidance on when to use local vs model-based mode
- AST/Prism quality improvements described for non-technical stakeholders

## 12. Current State

The gem now supports:
- Ruby/Rails/ERB code graph indexing
- richer call/render relationship extraction
- semantic code search with local or model-based embeddings
- CLI + MCP-style interfaces
- Neo4j-first graph backend support
- automated test coverage for parser, ingestor, semantic, and endpoint flows
