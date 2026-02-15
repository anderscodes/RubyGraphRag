# frozen_string_literal: true

require 'pathname'
require_relative 'constants'
require_relative 'config'
require_relative 'embedder'
require_relative 'vector_store'

module RubyGraphRag
  class GraphUpdater
    include RubyGraphRag::Constants

    attr_reader :repo_path, :ingestor, :function_registry, :simple_name_lookup, :association_registry, :ast_cache,
                :factory

    def initialize(repo_path:, ingestor:)
      @repo_path = Pathname.new(repo_path)
      @project_name = @repo_path.expand_path.basename.to_s
      @ingestor = ingestor
      @function_registry = {}
      @simple_name_lookup = Hash.new { |h, k| h[k] = Set.new }
      @association_registry = Hash.new { |h, k| h[k] = {} }
      @ast_cache = {}
      @factory = Parsers::ProcessorFactory.new(
        repo_path: @repo_path,
        project_name: @project_name,
        ingestor: @ingestor,
        function_registry: @function_registry,
        simple_name_lookup: @simple_name_lookup,
        association_registry: @association_registry
      )
    end

    def run
      @ingestor.ensure_node_batch(NODE_PROJECT, { 'name' => @project_name })
      @factory.structure_processor.identify_structure
      process_files
      process_associations
      process_function_calls
      process_rails
      @ingestor.flush_all
      generate_semantic_embeddings
    end

    def process_files
      @repo_path.glob('**/*').each do |path|
        next unless path.file?

        @factory.structure_processor.process_generic_file(path)
        next unless Config.ruby_extensions.include?(path.extname)

        parsed = @factory.definition_processor.process_file(path)
        @ast_cache[path] = parsed if parsed
      end
    end

    def process_function_calls
      @ast_cache.each_value do |parsed|
        @factory.call_processor.process_calls_in_file(parsed)
      end
    end

    def process_associations
      @factory.rails_association_processor.process
    end

    def process_rails
      @factory.rails_convention_processor.process
      views_dir = @repo_path + Config.views_dir
      return unless views_dir.directory?

      views_dir.glob('**/*.erb').each do |erb|
        @factory.erb_processor.process_erb_file(erb)
      end
    end

    def generate_semantic_embeddings
      return unless Config.semantic_enabled

      @ast_cache.each_value do |parsed|
        next if parsed.method_defs.empty?

        lines = parsed.text.lines
        parsed.method_defs.each_with_index do |method, idx|
          start_line = method[:line]
          end_line = idx + 1 < parsed.method_defs.length ? parsed.method_defs[idx + 1][:line] - 1 : lines.length
          source = lines[(start_line - 1)...end_line].join
          next if source.to_s.strip.empty?

          embedding = RubyGraphRag::Embedder.embed_code(source)
          node_id = RubyGraphRag::VectorStore.node_id_for(method[:qn])

          RubyGraphRag::VectorStore.store_embedding(
            node_id: node_id,
            embedding: embedding,
            payload: {
              'node_id' => node_id,
              'qualified_name' => method[:qn],
              'name' => method[:name],
              'type' => 'Function',
              'path' => parsed.path.relative_path_from(@repo_path).to_s,
              'start_line' => start_line,
              'end_line' => end_line,
              'source' => source
            }
          )
        end
      end
    end
  end
end
