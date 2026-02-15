# RubyGraphRag

RubyGraphRag is a Ruby gem for building a code knowledge graph from Ruby and Rails repositories.

It indexes source code into graph nodes/relationships so you can:
- understand structure (projects, folders, files, modules, classes, methods/functions),
- extract code relationships (`CALLS`, `INHERITS`, `RENDERS`),
- reason about Rails rendering conventions and ERB render calls,
- run semantic search over code intent with embeddings,
- query graph data through a Neo4j backend or an in-memory backend.

## Features

- Ruby parser pipeline for:
  - class/module/method extraction,
  - method/function call extraction (Prism AST-based),
  - inheritance extraction (`class A < B`).
- Rails support:
  - implicit controller-action view rendering convention detection,
  - explicit `render` resolution in controller code.
- ERB support:
  - detects `<% ... %>` Ruby blocks,
  - resolves `render` calls inside templates,
  - emits `RENDERS` from template file node to partial/template file node.
- Backends:
  - `InMemoryIngestor` (fast local development/testing),
  - `Neo4jBoltIngestor` (Bolt protocol via `neo4j-ruby-driver`).
- Embeddings:
  - `local_hash` (dependency-free default for offline/local usage),
  - `openai` (model-based embeddings through OpenAI-compatible `/embeddings` API).
- Tool surfaces:
  - Thor CLI (`index`, `query`, `watch`, `semantic_search`, `get_function_source`),
  - MCP-style endpoint dispatcher (`index_repository`, `list_directory`, `read_file`, `query_code_graph`, `semantic_code_search`, `get_function_source`).

## Architecture

Core entrypoint:
- `RubyGraphRag::GraphUpdater`

Pipeline executed by `GraphUpdater#run`:
1. Structure pass
   - creates `Project`, `Folder`, `File` nodes and containment relationships.
2. Definition pass
   - parses Ruby files and emits `Module`, `Class`, `Method`, `Function` nodes.
3. Call pass
   - uses Prism AST traversal with receiver-aware heuristics to emit `CALLS` edges more accurately.
4. Rails convention pass
   - emits `RENDERS` for implicit controller action templates.
5. ERB pass
   - scans `.erb` files for embedded Ruby and resolves `render` relationships.
6. Flush
   - persists all batched graph operations.
7. Semantic embedding pass
   - extracts method source, generates embeddings, and stores vectors for semantic search.

Main classes:
- `lib/ruby_graph_rag/graph_updater.rb`
- `lib/ruby_graph_rag/parsers/processor_factory.rb`
- `lib/ruby_graph_rag/parsers/definition_processor.rb`
- `lib/ruby_graph_rag/parsers/call_processor.rb`
- `lib/ruby_graph_rag/parsers/rails_convention_processor.rb`
- `lib/ruby_graph_rag/parsers/erb_processor.rb`
- `lib/ruby_graph_rag/services/in_memory_ingestor.rb`
- `lib/ruby_graph_rag/services/neo4j_bolt_ingestor.rb`
- `lib/ruby_graph_rag/mcp/tool_endpoints.rb`
- `lib/ruby_graph_rag/cli.rb`

Key parser/runtime dependencies:
- `prism` for Ruby AST-based call/render analysis.

## Getting Started

Prerequisites: Ruby `>= 3.2`, Bundler, and Docker (optional for Neo4j/Qdrant). Always run the commands from the `Gem/` directory so the bundled paths resolve correctly.

1. **Install dependencies**

   ```bash
   cd Gem
   BUNDLE_PATH=vendor/bundle ruby -S bundle install
   ```

2. **Start supporting services**

   - Neo4j (graph storage): `docker compose -f docker-compose.neo4j.yml up -d` or `make neo4j-up`.
   - Qdrant (semantic vector store): `docker run -d --rm -p 6333:6333 qdrant/qdrant` (add `-e QDRANT__SERVICE__API_KEY=your_key` if you protect the instance).
   - Override `QDRANT_URL`/`QDRANT_API_KEY` in the environment when using a remote service.

3. **Initialize the gem**

   ```bash
   cd Gem
   BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag index /home/anders/writebook/app  \
     --backend neo4j \
     --url bolt://127.0.0.1:7688 \
     --username neo4j \
     --password localdevpassword
   ```

   - Use `--backend in_memory` for short-lived experiments (perfect for CI or smoke tests).
   - The semantic backend stores vectors in Qdrant by default (`semantic_backend` config) while Neo4j handles the graph; ensure Qdrant is reachable before running `semantic_search` commands.

4. **Verify indexing**

   ```bash
   BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag query "MATCH (n) RETURN count(n)"
   BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag semantic_search "add two numbers"
   ```


## Installation

### As a local project gem (development)

From the gem directory:

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle install
```

### Add to another Ruby project

```ruby
# Gemfile
gem "RubyGraphRag", path: "/absolute/path/to/Gem"
```

Then:

```bash
bundle install
```

## CLI Usage

Executable:
- `exe/ruby-graph-rag`

### Index a repository

In-memory backend:

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag index /path/to/repo --backend in_memory
```

Neo4j backend:

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag index /path/to/repo \
  --backend neo4j \
  --url bolt://127.0.0.1:7688 \
  --username neo4j \
  --password your_password
```

### Query Neo4j directly (Cypher)

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag query "MATCH (n) RETURN count(n) AS nodes"
```

### Semantic search (local default backend)

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag semantic_search "add two numbers" --top-k 5
```

### Get source for a semantic match

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag get_function_source 123456789
```

### Watch a repository

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag watch /path/to/repo --backend in_memory
```

### Model-based embeddings (OpenAI-compatible)

Index with model embeddings:

```bash
cd Gem
OPENAI_API_KEY=your_key \
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag index /path/to/repo \
  --backend in_memory \
  --embedding-backend openai \
  --embedding-model text-embedding-3-small
```

Semantic search using the same backend:

```bash
cd Gem
OPENAI_API_KEY=your_key \
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag semantic_search "add two numbers" \
  --embedding-backend openai \
  --embedding-model text-embedding-3-small
```

Use an OpenAI-compatible gateway/self-hosted endpoint:

```bash
cd Gem
OPENAI_API_KEY=your_key \
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag semantic_search "auth logic" \
  --embedding-backend openai \
  --openai-base-url https://your-endpoint.example/v1 \
  --embedding-model text-embedding-3-small
```

## MCP-style Endpoint Usage

`RubyGraphRag::MCP::ToolEndpoints` provides simple method-dispatched tools.

```ruby
require_relative "lib/ruby_graph_rag"

mcp = RubyGraphRag::MCP::ToolEndpoints.new

mcp.list_tools
# => ["index_repository", "list_directory", "read_file", "query_code_graph", "semantic_code_search", "get_function_source"]

mcp.index_repository(repo_path: "/path/to/repo")
mcp.list_directory(repo_path: "/path/to/repo", directory_path: "app/views")
mcp.read_file(repo_path: "/path/to/repo", file_path: "app/controllers/users_controller.rb")
mcp.query_code_graph(repo_path: "/path/to/repo", query: "summary")
mcp.semantic_code_search(
  query: "add two numbers",
  embedding_backend: "openai",
  embedding_model: "text-embedding-3-small",
  openai_api_key: ENV["OPENAI_API_KEY"]
)
mcp.get_function_source(node_id: 123456789)
```

## Embedding Modes

`RubyGraphRag` supports two semantic embedding modes:

- `local_hash`:
  - default mode,
  - fully local and dependency-free,
  - best for fast offline development.
- `openai`:
  - model-based embeddings using an OpenAI-compatible API,
  - better intent-level semantic matching,
  - requires API key and network access.

Important:
- semantic vectors are persisted in Qdrant by default (`semantic_backend = qdrant`), and the collection name defaults to `ruby_graph_rag_embeddings`.
- this semantic store is separate from Neo4j graph storage, and you can point `QDRANT_URL`/`QDRANT_API_KEY` at managed Qdrant services as needed.
- use the `in_memory` semantic backend for short-lived runs or CI; it keeps vectors process-local and clears on exit.

## Neo4j Notes

`Neo4jBoltIngestor` uses Cypher over Bolt and works with Neo4j-compatible endpoints.

Requirements:
- running Neo4j instance,
- reachable Bolt URL (default `bolt://127.0.0.1:7688`).

You can wire your own connection settings via CLI flags or instantiate ingestor directly.

## Run Neo4j and Qdrant Locally with Docker

This gem includes a single Compose file that now brings up both Neo4j and Qdrant:
- `Gem/docker-compose.neo4j.yml`

### 1. Start Neo4j and Qdrant

```bash
cd Gem
docker compose -f docker-compose.neo4j.yml up -d
# or
make neo4j-up
```

### 2. Verify services are running

```bash
cd Gem
docker compose -f docker-compose.neo4j.yml ps
# or
make neo4j-ps
```

Follow logs:

```bash
cd Gem
make neo4j-logs
```

Open Neo4j Browser:
- `http://localhost:7474`

Default local credentials from the compose file:
- username: `neo4j`
- password: `localdevpassword`

Verify Qdrant is healthy:

```bash
curl http://localhost:6333/collections
```
You should see an empty `result` array from the Collections endpoint before any semantic data is indexed.

### 3. Index using the Neo4j backend

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag index /path/to/repo \
  --backend neo4j \
  --url bolt://127.0.0.1:7688 \
  --username neo4j \
  --password localdevpassword
```

### 4. Query Neo4j

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec exe/ruby-graph-rag query "MATCH (n) RETURN count(n) AS nodes" \
  --url bolt://127.0.0.1:7688 \
  --username neo4j \
  --password localdevpassword
```

### 5. Stop Neo4j

```bash
cd Gem
docker compose -f docker-compose.neo4j.yml down
# or
make neo4j-down
```

## Development Guide

### Prerequisites

- Ruby `>= 3.2`
- Bundler
- (Optional) Neo4j running locally for backend integration work

### Setup

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle install
```

### Run tests

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec rspec
```

### Run one spec file

```bash
cd Gem
BUNDLE_PATH=vendor/bundle ruby -S bundle exec rspec spec/ruby_graph_rag/graph_updater_spec.rb
```

### Coverage

`SimpleCov` is enabled by default in specs.
Coverage report is generated at:
- `Gem/coverage/index.html`

## Data Model (current)

Node labels:
- `Project`, `Folder`, `File`, `Module`, `Class`, `Method`, `Function`

Relationship types:
- `CONTAINS_FOLDER`, `CONTAINS_FILE`, `CONTAINS_MODULE`
- `DEFINES`, `DEFINES_METHOD`
- `CALLS`, `INHERITS`, `RENDERS`

## Current Scope and Limitations

- Parser implementation is intentionally lightweight for structure extraction, while call/render analysis uses Prism AST traversal.
- Focused on Ruby/Rails/ERB indexing workflow.
- Call resolution uses receiver-aware heuristics (including `self`, constant receivers, and lightweight `Class.new` local/ivar type inference), but it is not full type-flow analysis.
- MCP endpoint layer is a local dispatcher, not a network server process.
- `local_hash` embeddings are lower-quality than model-based embeddings for fuzzy intent matching.
- `openai` embedding quality depends on model choice and endpoint availability.

## Contributing

Typical loop:
1. Create/update specs in `spec/ruby_graph_rag/`.
2. Implement in `lib/ruby_graph_rag/`.
3. Run `bundle exec rspec`.
4. Keep behavior consistent between in-memory and Neo4j backends.

## License

MIT
