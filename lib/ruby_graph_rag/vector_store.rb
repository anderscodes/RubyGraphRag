# frozen_string_literal: true

require 'digest'
require_relative 'config'
require_relative 'vector_backends/in_memory_backend'
require_relative 'vector_backends/qdrant_backend'

module RubyGraphRag
  module VectorStore
    class << self
      def store_embedding(node_id:, embedding:, payload:)
        backend.store_embedding(node_id: node_id, embedding: embedding, payload: payload)
      rescue StandardError => e
        log_error('store_embedding', e)
        nil
      end

      def search_embeddings(query_embedding:, top_k: nil)
        backend.search_embeddings(query_embedding: query_embedding, top_k: top_k)
      rescue StandardError => e
        log_error('search_embeddings', e)
        []
      end

      def payload_for(node_id)
        backend.payload_for(node_id)
      rescue StandardError => e
        log_error('payload_for', e)
        nil
      end

      def clear!
        backend.clear!
      rescue StandardError => e
        log_error('clear!', e)
      ensure
        reset_store!
      end

      def reset_store!
        @backend = nil
      end

      def node_id_for(qualified_name)
        Digest::SHA256.hexdigest(qualified_name.to_s)[0, 16].to_i(16)
      end

      private

      def backend
        @backend ||= select_backend
      end

      def select_backend
        case RubyGraphRag::Config.semantic_backend.to_s
        when 'qdrant'
          RubyGraphRag::VectorBackends::QdrantBackend.new
        else
          RubyGraphRag::VectorBackends::InMemoryBackend.new
        end
      rescue StandardError => e
        RubyGraphRag.logger.warn(
          "VectorStore backend #{RubyGraphRag::Config.semantic_backend} unavailable; " \
          "falling back to in-memory: #{e.message}"
        )
        RubyGraphRag::VectorBackends::InMemoryBackend.new
      end

      def log_error(method, exception)
        RubyGraphRag.logger.error("VectorStore##{method} failed: #{exception.message}")
      end
    end
  end
end
