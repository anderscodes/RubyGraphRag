# frozen_string_literal: true

require 'json'
require 'pathname'
require 'thor'
require_relative 'graph_updater'
require_relative 'realtime/watcher'
require_relative 'services/in_memory_ingestor'
require_relative 'services/neo4j_bolt_ingestor'
require_relative 'tools/semantic_search'

module RubyGraphRag
  class CLI < Thor
    desc 'index PATH', 'Index repository into graph'
    option :backend, type: :string, default: 'in_memory', enum: %w[in_memory neo4j]
    option :url, type: :string, default: 'bolt://127.0.0.1:7688'
    option :username, type: :string, default: ''
    option :password, type: :string, default: ''
    option :embedding_backend, type: :string, default: 'local_hash', enum: %w[local_hash openai]
    option :embedding_model, type: :string, default: RubyGraphRag::Config.embedding_model
    option :openai_base_url, type: :string, default: RubyGraphRag::Config.openai_base_url
    option :openai_api_key, type: :string, default: ''
    def index(path)
      configure_embedding_from_options(options)
      repo = Pathname.new(path).expand_path
      ingestor = build_ingestor(options)
      updater = RubyGraphRag::GraphUpdater.new(repo_path: repo, ingestor: ingestor)
      updater.run

      if ingestor.respond_to?(:nodes)
        puts JSON.pretty_generate({ status: 'ok', repo: repo.to_s, nodes: ingestor.nodes.size,
                                    relationships: ingestor.relationships.size })
      else
        puts JSON.pretty_generate({ status: 'ok', repo: repo.to_s })
      end
    ensure
      ingestor&.close if ingestor.respond_to?(:close)
    end

    desc 'query CYPHER', 'Run a Cypher query against Neo4j'
    option :url, type: :string, default: 'bolt://127.0.0.1:7688'
    option :username, type: :string, default: ''
    option :password, type: :string, default: ''
    def query(cypher)
      ingestor = RubyGraphRag::Services::Neo4jBoltIngestor.new(
        url: options[:url],
        username: options[:username],
        password: options[:password]
      )
      rows = ingestor.fetch_all(cypher)
      puts JSON.pretty_generate(rows)
    ensure
      ingestor&.close
    end

    desc 'watch PATH', 'Watch repository and re-index on change'
    option :backend, type: :string, default: 'in_memory', enum: %w[in_memory neo4j]
    option :url, type: :string, default: 'bolt://127.0.0.1:7688'
    option :username, type: :string, default: ''
    option :password, type: :string, default: ''
    option :embedding_backend, type: :string, default: 'local_hash', enum: %w[local_hash openai]
    option :embedding_model, type: :string, default: RubyGraphRag::Config.embedding_model
    option :openai_base_url, type: :string, default: RubyGraphRag::Config.openai_base_url
    option :openai_api_key, type: :string, default: ''
    def watch(path)
      configure_embedding_from_options(options)
      repo = Pathname.new(path).expand_path
      ingestor = build_ingestor(options)
      updater = RubyGraphRag::GraphUpdater.new(repo_path: repo, ingestor: ingestor)
      updater.run
      puts "Initial index complete for #{repo}. Watching for changes..."
      RubyGraphRag::Realtime::Watcher.new(repo_path: repo, updater: updater).start
    end

    desc 'semantic_search QUERY', 'Run semantic search over indexed functions'
    option :top_k, type: :numeric, default: 5
    option :embedding_backend, type: :string, default: 'local_hash', enum: %w[local_hash openai]
    option :embedding_model, type: :string, default: RubyGraphRag::Config.embedding_model
    option :openai_base_url, type: :string, default: RubyGraphRag::Config.openai_base_url
    option :openai_api_key, type: :string, default: ''
    def semantic_search(query)
      configure_embedding_from_options(options)
      results = RubyGraphRag::Tools::SemanticSearch.semantic_code_search(query, top_k: options[:top_k].to_i)
      puts JSON.pretty_generate({ status: 'ok', results: results })
    end

    desc 'get_function_source NODE_ID', 'Get indexed function source by semantic node id'
    def get_function_source(node_id)
      source = RubyGraphRag::Tools::SemanticSearch.get_function_source_code(node_id.to_i)
      if source
        puts JSON.pretty_generate({ status: 'ok', node_id: node_id.to_i, source: source })
      else
        puts JSON.pretty_generate({ status: 'error', message: 'Source not found', node_id: node_id.to_i })
      end
    end

    private

    def configure_embedding_from_options(opts)
      RubyGraphRag::Config.config.embedding_backend = opts[:embedding_backend].to_s
      RubyGraphRag::Config.config.embedding_model = opts[:embedding_model].to_s if opts[:embedding_model]
      RubyGraphRag::Config.config.openai_base_url = opts[:openai_base_url].to_s if opts[:openai_base_url]
      return unless opts[:openai_api_key] && !opts[:openai_api_key].to_s.empty?

      RubyGraphRag::Config.config.openai_api_key = opts[:openai_api_key].to_s
    end

    def build_ingestor(opts)
      return RubyGraphRag::Services::InMemoryIngestor.new if opts[:backend] == 'in_memory'

      RubyGraphRag::Services::Neo4jBoltIngestor.new(
        url: opts[:url],
        username: opts[:username],
        password: opts[:password]
      )
    end
  end
end
