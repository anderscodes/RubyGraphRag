# Plan: Bring ruby_graph_rag to Feature Parity with Python graph_code

## Context

The `ruby_graph_rag` gem (at `Rag_a_Ruby/Gem/`) is a Graph-based RAG indexer for Ruby/Rails codebases. It builds a knowledge graph of code structure and supports semantic search. The Python `graph_code` package has substantially more features: an AI agent layer with natural-language-to-Cypher, code modification tools, richer graph schema (imports, dependencies), export capabilities, and operational tooling.

This plan brings the Ruby gem to feature parity (excluding document analysis and limiting LLM providers to OpenAI, Anthropic, and Ollama). Serialization will use MessagePack instead of Protobuf.

## Decision Log

- **Skip**: Document analysis (PDF/image) -- orthogonal to code RAG
- **MessagePack** over Protobuf for offline indexing -- lighter, faster, no schema files
- **LLM providers**: OpenAI + Anthropic + Ollama (Ollama via OpenAI-compatible API)
- **Agent loop**: Simple Ruby loop, no external framework -- Ruby lacks a mature equivalent to `pydantic_ai`
- **Optional deps**: LLM gems loaded lazily so users who only index don't need them

---

## Phase 0: Parity Foundations (Must-Have Before Agent Features)

**Goal**: Establish stable contracts, safety baselines, and measurable quality gates before adding higher-level agent behavior.

### 0A. Graph Schema Contract + Versioning

**New file**: `lib/ruby_graph_rag/schema.rb`
- Define canonical node/relationship types, required properties, and identity keys
- Include schema version constant (e.g. `SCHEMA_VERSION = 1`)
- Expose helpers used by exporters and Cypher-generation tooling

**New file**: `docs/graph-schema.md`
- Human-readable schema reference used by LLM prompt builders and maintainers

**Modify**: `constants.rb` -- align with schema contract source of truth
**New test**: `spec/ruby_graph_rag/schema_spec.rb`

### 0B. Stable Identity + Migration Guardrails

**Modify**: `graph_updater.rb`, `services/*_ingestor.rb`
- Enforce deterministic node identity policy across in-memory, Neo4j, JSON, and MessagePack
- Add schema version stamping in exported artifacts
- Add migration check/fail-fast when loading incompatible offline artifacts

**New test**: `spec/ruby_graph_rag/schema_migration_spec.rb`

### 0C. Evaluation Harness + Goldens

**New folder**: `spec/fixtures/parity/`
- Small representative repos/snippets for Rails and plain Ruby patterns

**New file**: `spec/ruby_graph_rag/parity_evaluation_spec.rb`
- Goldens for `CALLS`, `INHERITS`, `RENDERS`
- Quality gates for semantic search ranking stability
- Baseline checks for future NL→Cypher accuracy tests

---

## Phase 1: Graph Schema Enrichment

**Goal**: Enrich the knowledge graph with import/require tracking, dependency analysis, and ignore file support. No new gem dependencies.

### 1A. Import/Require Processor

Track `require`, `require_relative`, and `load` statements as `IMPORTS` relationships.

**New file**: `lib/ruby_graph_rag/parsers/import_processor.rb`
- Walk Prism AST for CallNodes named `require`, `require_relative`, `load`
- Resolve string arguments to file paths within the repo
- `require "foo"` → look for `lib/foo.rb` or `foo.rb`; if not found, treat as external
- `require_relative "bar"` → resolve relative to current file's directory
- Emit `IMPORTS` relationship from current Module to target Module/File

**Modify**: `constants.rb` -- add `REL_IMPORTS = "IMPORTS"`
**Modify**: `parsers/processor_factory.rb` -- add `import_processor` lazy accessor
**Modify**: `graph_updater.rb` -- call import processor after definition pass (uses AST cache)
**New test**: `spec/ruby_graph_rag/import_processor_spec.rb`

### 1B. Dependency Processor (Gemfile/gemspec)

Parse `Gemfile` and `*.gemspec` to create `ExternalPackage` nodes and `DEPENDS_ON_EXTERNAL` relationships.

**New file**: `lib/ruby_graph_rag/parsers/dependency_processor.rb`
- Regex parse `Gemfile` for `gem "name"` lines
- Regex parse `*.gemspec` for `add_dependency` / `add_runtime_dependency`
- Create `ExternalPackage` node per dependency
- Emit `DEPENDS_ON_EXTERNAL` from Project to each ExternalPackage

**Modify**: `constants.rb` -- add `NODE_EXTERNAL_PACKAGE`, `REL_DEPENDS_ON_EXTERNAL`
**Modify**: `parsers/processor_factory.rb` -- add `dependency_processor` lazy accessor
**Modify**: `graph_updater.rb` -- call after structure pass
**New test**: `spec/ruby_graph_rag/dependency_processor_spec.rb`

Extend dependency coverage:
- Parse `Gemfile.lock` for resolved versions
- Add package-level node(s) for the indexed project
- Link project/package to resolved dependency versions

### 1C. Ignore File Support

**New file**: `lib/ruby_graph_rag/ignore_file.rb`
- Read `.rubygraphragignore` from repo root
- Parse gitignore-style patterns using `File.fnmatch` with `FNM_PATHNAME`
- Expose `should_skip?(relative_path)` method
- Support `#` comments, `!` negation patterns

**Modify**: `graph_updater.rb` -- filter files through `IgnoreFile` in `process_files`
**Modify**: `config.rb` -- add `setting :ignore_file_name, default: ".rubygraphragignore"`
**New test**: `spec/ruby_graph_rag/ignore_file_spec.rb`

### 1D. Relationship Parity Expansion

Add relationship types currently missing from the Ruby graph but present in Python parity targets.

**Modify**: `constants.rb` -- add `REL_EXPORTS`, `REL_OVERRIDES`, `REL_INCLUDES`, `REL_PREPENDS`
**Modify**: `parsers/*` -- enrich extraction logic for:
- `EXPORTS` (public APIs, constants/modules exposed)
- `OVERRIDES` (method overrides across inheritance chains)
- `INCLUDES` / `PREPENDS` (Ruby mixin semantics)

**New test**: `spec/ruby_graph_rag/relationship_parity_spec.rb`

---

## Phase 2: Export & Storage

**Goal**: Enable graph export (JSON, MessagePack) and optimize Neo4j ingestion with batching.

**New dependency**: `msgpack ~> 1.7`

### 2A. Graph Export to JSON

**New file**: `lib/ruby_graph_rag/export/json_exporter.rb`
- For `InMemoryIngestor`: serialize `.nodes` hash + `.relationships` set
- For `Neo4jBoltIngestor`: run `MATCH (n) RETURN n` and `MATCH ()-[r]->() RETURN r`
- Write to file path or return hash

**Modify**: `cli.rb` -- add `export PATH` command with `--format json` option
**Modify**: `mcp/tool_endpoints.rb` -- add `export_graph` tool
**New test**: `spec/ruby_graph_rag/json_exporter_spec.rb`

### 2B. MessagePack Offline Indexing

**New file**: `lib/ruby_graph_rag/export/msgpack_exporter.rb`
- Implements the `Ingestor` interface (include `Services::Ingestor`)
- Accumulates nodes/relationships in memory during pipeline
- On `flush_all`, serializes to `.msgpack` binary file
- Class method `self.load(path)` to deserialize back to node/relationship hashes

**Modify**: `cli.rb` -- add `--format msgpack` option to `index` and `export` commands
**Modify**: `ruby_graph_rag.gemspec` -- add `msgpack` dependency
**New test**: `spec/ruby_graph_rag/msgpack_exporter_spec.rb`

### 2C. Batched Neo4j Ingestion

**Modify**: `services/neo4j_bolt_ingestor.rb`
- Add internal `@node_buffer` and `@rel_buffer` arrays
- Buffer operations in `ensure_node_batch` / `ensure_relationship_batch`
- Flush when buffer reaches `batch_size` (default 1000)
- Use Cypher `UNWIND $batch AS row MERGE ...` for batch writes
- `flush_all` drains both buffers

**Modify**: `config.rb` -- add `setting :neo4j_batch_size, default: 1000`
**Update test**: `spec/ruby_graph_rag/neo4j_bolt_ingestor_spec.rb` -- add batching tests

---

## Phase 3: Operational Features

**Goal**: Improve usability with health checks, session logging, and interactive setup. No new dependencies.

### 3A. Health Check / Doctor Command

**New file**: `lib/ruby_graph_rag/tools/health_checker.rb`
- `check_neo4j_connection` -- try connecting to configured Neo4j URL
- `check_embedding_config` -- verify API key if OpenAI backend selected
- `check_dependencies` -- verify required gems are loadable
- `check_docker` -- `docker info` subprocess for Neo4j container
- Returns structured results: `[{name:, status: :ok/:error, message:}]`

**Modify**: `cli.rb` -- add `doctor` command
**New test**: `spec/ruby_graph_rag/health_checker_spec.rb`

### 3B. Session Logging

**New file**: `lib/ruby_graph_rag/session_logger.rb`
- Append timestamped JSONL entries to log file
- Log events: index_start, index_complete, query, semantic_search, tool_call, error
- Configurable log directory

**Modify**: `config.rb` -- add `setting :session_logging_enabled, default: false`, `setting :session_log_dir, default: ".ruby_graph_rag_logs"`
**New test**: `spec/ruby_graph_rag/session_logger_spec.rb`

### 3C. Interactive Setup Wizard

**Modify**: `cli.rb` -- add `setup` command (~40 lines)
- Use Thor's `ask` and `yes?` prompts
- Configure: graph backend, Neo4j connection, embedding backend, API keys
- Write results to `.env` or `.ruby_graph_rag.yml`
- Optionally run `doctor` after setup

### 3D. Incremental Indexing + Deletion Handling

**Modify**: `realtime/watcher.rb`, `graph_updater.rb`
- Incremental updates for changed files without full reindex
- Explicit delete handling (remove stale file/function nodes and edges)
- Stale-edge cleanup for modified files

**New test**: `spec/ruby_graph_rag/incremental_indexing_spec.rb`

---

## Phase 4: AI Agent Layer

**Goal**: Add multi-provider LLM support, natural-language-to-Cypher, and an agent orchestrator with tool chaining.

**New dependencies**: `ruby-openai ~> 7.0` (runtime, optional), `anthropic-sdk-ruby ~> 0.3` (runtime, optional)

Both loaded lazily -- only required when user configures an LLM provider.

### 4A. Multi-Provider LLM Client

**New files**:
- `lib/ruby_graph_rag/llm/provider.rb` -- base module with `REGISTRY` hash and `self.provider_for(name, **config)` factory
- `lib/ruby_graph_rag/llm/openai_provider.rb` -- wraps `ruby-openai` gem; also handles Ollama via custom `base_url`
- `lib/ruby_graph_rag/llm/anthropic_provider.rb` -- wraps `anthropic-sdk-ruby`

Provider interface:
```ruby
def chat(messages:, tools: nil, model: nil) → Response
# Response has: .content (String), .tool_calls (Array), .to_message (Hash)
```

**Modify**: `config.rb` -- add settings:
- `orchestrator_provider` (default: `"openai"`)
- `orchestrator_model` (default: `"gpt-4o"`)
- `orchestrator_api_key` (default: `ENV["OPENAI_API_KEY"]`)
- `orchestrator_base_url` (default: `"https://api.openai.com/v1"`)
- `cypher_provider`, `cypher_model`, `cypher_api_key`, `cypher_base_url` (same pattern)

**New test**: `spec/ruby_graph_rag/llm/openai_provider_spec.rb` (WebMock stubs)

### 4B. Natural Language to Cypher

**New file**: `lib/ruby_graph_rag/llm/cypher_generator.rb`
- System prompt describes the graph schema (all node types, relationship types, property names)
- Sends user's natural language question to the cypher-specific LLM provider
- Parses response, strips markdown fences, validates basic Cypher structure
- Returns cleaned Cypher query string
- Enforce read-only mode by default (deny `CREATE`, `MERGE`, `DELETE`, `SET`, `DROP`, etc. unless explicitly enabled)

**Modify**: `cli.rb` -- add `ask QUESTION` command
**Modify**: `mcp/tool_endpoints.rb` -- enhance `query_code_graph` to accept natural language when LLM is configured
**New test**: `spec/ruby_graph_rag/llm/cypher_generator_spec.rb`

### 4C. Agent Orchestrator

**New files**:
- `lib/ruby_graph_rag/llm/tool.rb` -- `Tool = Struct.new(:name, :description, :parameters, :handler, keyword_init: true)`
- `lib/ruby_graph_rag/llm/orchestrator.rb` -- agent loop

Orchestrator design:
- Accepts a provider, array of Tools, and system prompt
- `run(user_query)` enters a loop (max 10 iterations):
  1. Send messages + tool definitions to LLM
  2. If response has tool_calls → execute each, append results, loop
  3. If response is text → return as final answer
- Tools are the existing MCP tool methods wrapped as `LLM::Tool` structs

**Modify**: `cli.rb` -- add `chat` command for interactive agent session (REPL loop)
**New test**: `spec/ruby_graph_rag/llm/orchestrator_spec.rb`

---

## Phase 5: Code Modification Tools

**Goal**: Add surgical code editing, file creation, and shell command execution. Register all new tools with MCP and CLI.

**New dependency**: `diffy ~> 3.4` for unified diff generation

### 5A. Surgical Code Editing

**New file**: `lib/ruby_graph_rag/tools/file_editor.rb`
- `replace_code(file_path:, old_code:, new_code:)` -- find and replace exact code block
- `replace_function(file_path:, function_name:, new_code:, line_hint: nil)` -- use Prism AST to locate function, replace its body
- `preview_diff(file_path:, old_code:, new_code:)` -- return unified diff string (via `diffy`)
- Security: validate all paths within project root

**Modify**: `ruby_graph_rag.gemspec` -- add `diffy` dependency
**New test**: `spec/ruby_graph_rag/tools/file_editor_spec.rb`

### 5B. File Creation/Writing

**New file**: `lib/ruby_graph_rag/tools/file_writer.rb`
- `create_file(file_path:, content:)` -- validate path is within project root, create parent dirs, write file
- `write_file(file_path:, content:)` -- overwrite existing file (with warning if it exists)

**New test**: `spec/ruby_graph_rag/tools/file_writer_spec.rb`

### 5C. Shell Command Execution

**New file**: `lib/ruby_graph_rag/tools/shell_commander.rb`
- Configurable allowlist (default: `ls, cat, head, tail, wc, grep, rg, git, bundle, rake, rspec, find, sort, uniq`)
- Configurable read-only commands that skip confirmation
- Validate command against allowlist before execution
- `Open3.capture3` with configurable timeout (default 30s)
- Returns `{stdout:, stderr:, exit_status:}`
- Add policy gates for mutating commands (explicit approval path + audit event)

**Modify**: `config.rb` -- add `setting :shell_command_timeout, default: 30`, `setting :shell_command_allowlist, default: [...]`
**New test**: `spec/ruby_graph_rag/tools/shell_commander_spec.rb`

### 5D. Tool Safety Policy + Audit Trail

**New file**: `lib/ruby_graph_rag/tools/safety_policy.rb`
- Central policy engine for tool execution modes: `read_only`, `interactive_approval`, `unrestricted`
- Enforce per-tool risk classes (`query`, `file_write`, `shell`, `graph_write`)

**Modify**: `session_logger.rb`
- Include policy decisions and approval outcomes in structured logs

**New test**: `spec/ruby_graph_rag/tools/safety_policy_spec.rb`

### 5E. Register All New Tools

**Modify**: `mcp/tool_endpoints.rb` -- add to `list_tools` and `call_tool`:
- `replace_code` → `FileEditor#replace_code`
- `create_file` → `FileWriter#create_file`
- `execute_shell` → `ShellCommander#execute`
- `ask_codebase` → `Orchestrator#run` (agent-based Q&A)
- `export_graph` → `JsonExporter#export`
- `doctor` → `HealthChecker#run_all_checks`

**Modify**: `cli.rb` -- ensure all new tools are also available as CLI commands

---

## Phase 6: Production Retrieval Parity (Optional but High Value)

**Goal**: Match Python package behavior in large-codebase retrieval quality and scale.

### 6A. Pluggable Vector Backend Interface

**Implemented**: `lib/ruby_graph_rag/vector_store.rb` routes requests through `RubyGraphRag::VectorBackends`, defaulting to `VectorBackends::QdrantBackend` but falling back to `VectorBackends::InMemoryBackend` when `semantic_backend` is overridden or Qdrant is unavailable. The interface is maintained via shared method signatures rather than a separate base file.

### 6B. Optional Qdrant Adapter

**New file**: `lib/ruby_graph_rag/vector_backends/qdrant_backend.rb`
- Qdrant backend shipped as the default semantic backend; no additional runtime opt-in is required (just point `QDRANT_URL` to your instance).
- `VectorBackends::InMemoryBackend` remains available for fast local runs/CI when you don't want to start Qdrant.

### 6C. Code Optimization Agent Tool

**New file**: `lib/ruby_graph_rag/tools/code_optimizer.rb`
- LLM-assisted refactoring suggestions with diff preview and explicit approval
- Keep separate from surgical editor tool to preserve reviewability

---

## New Files Summary

```
lib/ruby_graph_rag/
  parsers/
    import_processor.rb              # Phase 1A
    dependency_processor.rb          # Phase 1B
  ignore_file.rb                     # Phase 1C
  export/
    json_exporter.rb                 # Phase 2A
    msgpack_exporter.rb              # Phase 2B
  tools/
    health_checker.rb                # Phase 3A
    file_editor.rb                   # Phase 5A
    file_writer.rb                   # Phase 5B
    shell_commander.rb               # Phase 5C
  llm/
    provider.rb                      # Phase 4A
    openai_provider.rb               # Phase 4A
    anthropic_provider.rb            # Phase 4A
    cypher_generator.rb              # Phase 4B
    orchestrator.rb                  # Phase 4C
    tool.rb                          # Phase 4C
  session_logger.rb                  # Phase 3B

spec/ruby_graph_rag/
  import_processor_spec.rb           # Phase 1A
  dependency_processor_spec.rb       # Phase 1B
  ignore_file_spec.rb                # Phase 1C
  json_exporter_spec.rb              # Phase 2A
  msgpack_exporter_spec.rb           # Phase 2B
  health_checker_spec.rb             # Phase 3A
  session_logger_spec.rb             # Phase 3B
  llm/
    openai_provider_spec.rb          # Phase 4A
    cypher_generator_spec.rb         # Phase 4B
    orchestrator_spec.rb             # Phase 4C
  tools/
    file_editor_spec.rb              # Phase 5A
    file_writer_spec.rb              # Phase 5B
    shell_commander_spec.rb          # Phase 5C
```

## Modified Files Summary

| File | Phases | Changes |
|------|--------|---------|
| `lib/ruby_graph_rag.rb` | All | Add `require_relative` for all new files |
| `lib/ruby_graph_rag/constants.rb` | 1A, 1B | Add `REL_IMPORTS`, `NODE_EXTERNAL_PACKAGE`, `REL_DEPENDS_ON_EXTERNAL` |
| `lib/ruby_graph_rag/config.rb` | 1C, 2C, 3B, 4A, 5C | Add ~15 new config settings |
| `lib/ruby_graph_rag/graph_updater.rb` | 1A, 1B, 1C | Add import, dependency, and ignore file steps to pipeline |
| `lib/ruby_graph_rag/parsers/processor_factory.rb` | 1A, 1B | Add `import_processor` and `dependency_processor` lazy accessors |
| `lib/ruby_graph_rag/services/neo4j_bolt_ingestor.rb` | 2C | Add batching with UNWIND queries |
| `lib/ruby_graph_rag/cli.rb` | 2A, 3A, 3C, 4B, 4C | Add `export`, `doctor`, `setup`, `ask`, `chat` commands |
| `lib/ruby_graph_rag/mcp/tool_endpoints.rb` | 2A, 5D | Add 6 new tool methods and dispatch entries |
| `ruby_graph_rag.gemspec` | 2B, 4A, 5A | Add `msgpack`, `ruby-openai`, `anthropic-sdk-ruby`, `diffy` |

## New Dependencies

| Gem | Phase | Type | Purpose |
|-----|-------|------|---------|
| `msgpack ~> 1.7` | 2B | Runtime | Offline graph serialization |
| `ruby-openai ~> 7.0` | 4A | Runtime (lazy) | OpenAI + Ollama LLM provider |
| `anthropic-sdk-ruby ~> 0.3` | 4A | Runtime (lazy) | Anthropic LLM provider |
| `diffy ~> 3.4` | 5A | Runtime | Unified diff generation for code editing |

LLM gems are loaded lazily (`require` inside the provider class) so users who only use indexing features don't need them installed.

## Verification

After each phase, run:
```bash
cd Rag_a_Ruby/Gem && bundle exec rspec
```

After all phases:
1. **Index a Rails repo**: `ruby_graph_rag index /path/to/rails/app --backend neo4j`
2. **Check graph enrichment**: `ruby_graph_rag query "MATCH ()-[r:IMPORTS]->() RETURN count(r)"` and `MATCH (n:ExternalPackage) RETURN n`
3. **Export graph**: `ruby_graph_rag export /path/to/rails/app --format json -o graph.json`
4. **Run doctor**: `ruby_graph_rag doctor`
5. **Ask natural language**: `ruby_graph_rag ask "What classes inherit from ApplicationController?"`
6. **Interactive chat**: `ruby_graph_rag chat --repo /path/to/rails/app`
7. **MCP tools**: Test each new tool via `call_tool` dispatch
