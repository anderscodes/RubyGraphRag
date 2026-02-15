# frozen_string_literal: true

require 'pathname'
require_relative '../config'
require_relative '../graph_updater'
require_relative '../services/in_memory_ingestor'
require_relative '../tools/semantic_search'

module RubyGraphRag
  module MCP
    # Provides RPC-style entry points for indexing, querying, and semantic search.
    class ToolEndpoints
      def initialize
        @indexed_projects = {}
      end

      TOOL_DISPATCH = {
        'index_repository' => :index_repository,
        'list_directory' => :list_directory,
        'read_file' => :read_file,
        'query_code_graph' => :query_code_graph,
        'semantic_code_search' => :semantic_code_search,
        'get_function_source' => :get_function_source
      }.freeze

      def list_tools
        %w[index_repository list_directory read_file query_code_graph semantic_code_search get_function_source]
      end

      def index_repository(repo_path:)
        path = Pathname.new(repo_path).expand_path
        ingestor = RubyGraphRag::Services::InMemoryIngestor.new
        RubyGraphRag::GraphUpdater.new(repo_path: path, ingestor: ingestor).run
        @indexed_projects[path.to_s] = ingestor
        {
          status: 'ok',
          project: path.basename.to_s,
          nodes: ingestor.nodes.size,
          relationships: ingestor.relationships.size
        }
      end

      def list_directory(repo_path:, directory_path: '.')
        base = Pathname.new(repo_path).expand_path
        dir = (base + directory_path).expand_path
        raise ArgumentError, 'Directory outside repository' unless dir.to_s.start_with?(base.to_s)
        raise ArgumentError, 'Not a directory' unless dir.directory?

        dir.children.sort.map { |p| p.relative_path_from(base).to_s }
      end

      def read_file(repo_path:, file_path:)
        base = Pathname.new(repo_path).expand_path
        file = (base + file_path).expand_path
        raise ArgumentError, 'File outside repository' unless file.to_s.start_with?(base.to_s)
        raise ArgumentError, 'Not a file' unless file.file?

        file.read
      end

      def query_code_graph(repo_path:, query:)
        path = Pathname.new(repo_path).expand_path.to_s
        ingestor = @indexed_projects[path]
        return { status: 'error', message: 'Repository not indexed' } unless ingestor

        normalized = query.to_s.downcase.strip
        case normalized
        when 'counts', 'summary'
          {
            status: 'ok',
            nodes: ingestor.nodes.size,
            relationships: ingestor.relationships.size
          }
        when /renders/
          rels = ingestor.relationships.select { |r| r[1] == 'RENDERS' }
          { status: 'ok', results: rels }
        when /calls/
          rels = ingestor.relationships.select { |r| r[1] == 'CALLS' }
          { status: 'ok', results: rels }
        else
          { status: 'ok', nodes: ingestor.nodes.values.take(25), relationships: ingestor.relationships.to_a.take(25) }
        end
      end

      def semantic_code_search(query:, top_k: 5, embedding_backend: nil, embedding_model: nil, openai_base_url: nil,
                               openai_api_key: nil)
        configure_embedding(
          embedding_backend: embedding_backend,
          embedding_model: embedding_model,
          openai_base_url: openai_base_url,
          openai_api_key: openai_api_key
        )
        {
          status: 'ok',
          results: RubyGraphRag::Tools::SemanticSearch.semantic_code_search(query, top_k: top_k)
        }
      end

      def get_function_source(node_id:)
        source = RubyGraphRag::Tools::SemanticSearch.get_function_source_code(node_id.to_i)
        return { status: 'error', message: 'Source not found' } unless source

        { status: 'ok', node_id: node_id.to_i, source: source }
      end

      def call_tool(name, params = {})
        tool = TOOL_DISPATCH[name.to_s]
        raise ArgumentError, "Unknown tool: #{name}" unless tool

        send(tool, **params.transform_keys(&:to_sym))
      end

      private

      def configure_embedding(embedding_backend:, embedding_model:, openai_base_url:, openai_api_key:)
        RubyGraphRag::Config.config.embedding_backend = embedding_backend.to_s unless embedding_backend.nil?
        RubyGraphRag::Config.config.embedding_model = embedding_model.to_s unless embedding_model.nil?
        RubyGraphRag::Config.config.openai_base_url = openai_base_url.to_s unless openai_base_url.nil?
        return if openai_api_key.nil? || openai_api_key.to_s.empty?

        RubyGraphRag::Config.config.openai_api_key = openai_api_key.to_s
      end
    end
  end
end
