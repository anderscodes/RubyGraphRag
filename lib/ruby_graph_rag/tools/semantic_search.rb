# frozen_string_literal: true

require_relative '../config'
require_relative '../embedder'
require_relative '../vector_store'

module RubyGraphRag
  module Tools
    module SemanticSearch
      class << self
        def semantic_code_search(query, top_k: nil)
          query_embedding = RubyGraphRag::Embedder.embed_code(query)
          hits = RubyGraphRag::VectorStore.search_embeddings(query_embedding: query_embedding, top_k: top_k)

          hits.map do |node_id, score|
            payload = RubyGraphRag::VectorStore.payload_for(node_id) || {}
            {
              node_id: node_id,
              qualified_name: payload['qualified_name'] || 'unknown',
              name: payload['name'] || 'unknown',
              type: payload['type'] || 'Unknown',
              score: score.round(3)
            }
          end
        rescue StandardError => e
          RubyGraphRag.logger.error("SemanticSearch failed: #{e.message}")
          []
        end

        def get_function_source_code(node_id)
          payload = RubyGraphRag::VectorStore.payload_for(node_id)
          payload && payload['source']
        end
      end
    end
  end
end
