# frozen_string_literal: true

require_relative 'ruby_graph_rag/version'
require_relative 'ruby_graph_rag/config'
require_relative 'ruby_graph_rag/constants'
require_relative 'ruby_graph_rag/services/ingestor'
require_relative 'ruby_graph_rag/services/in_memory_ingestor'
require_relative 'ruby_graph_rag/services/neo4j_bolt_ingestor'
require_relative 'ruby_graph_rag/parsers/processor_factory'
require_relative 'ruby_graph_rag/graph_updater'
require_relative 'ruby_graph_rag/embedder'
require_relative 'ruby_graph_rag/vector_store'
require_relative 'ruby_graph_rag/tools/semantic_search'
require_relative 'ruby_graph_rag/realtime/watcher'
require_relative 'ruby_graph_rag/mcp/tool_endpoints'
require_relative 'ruby_graph_rag/cli'

module RubyGraphRag
  class Error < StandardError; end
  class EmbeddingError < Error; end
  class StoreError < Error; end

  class << self
    attr_writer :logger

    def logger
      @logger ||= begin
        require 'logger'
        Logger.new($stderr, level: Logger::WARN)
      end
    end
  end
end
