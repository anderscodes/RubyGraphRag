# frozen_string_literal: true

require_relative '../constants'

module RubyGraphRag
  module VectorBackends
    class InMemoryBackend
      def initialize
        @vectors = {}
      end

      def store_embedding(node_id:, embedding:, payload:)
        @vectors[node_id.to_i] = { embedding: embedding, payload: payload }
      end

      def search_embeddings(query_embedding:, top_k: nil)
        limit = top_k || RubyGraphRag::Config.semantic_top_k
        rows = @vectors.map do |node_id, entry|
          score = cosine_similarity(query_embedding, entry[:embedding])
          [node_id, score]
        end
        rows.sort_by { |(_id, score)| -score }.first(limit)
      end

      def payload_for(node_id)
        entry = @vectors[node_id.to_i]
        entry && entry[:payload]
      end

      def clear!
        @vectors.clear
      end

      private

      def cosine_similarity(vec_a, vec_b)
        dot = 0.0
        norm_a = 0.0
        norm_b = 0.0
        len = [vec_a.length, vec_b.length].min
        i = 0
        while i < len
          av = vec_a[i]
          bv = vec_b[i]
          dot += av * bv
          norm_a += av * av
          norm_b += bv * bv
          i += 1
        end
        return 0.0 if norm_a.zero? || norm_b.zero?

        dot / Math.sqrt(norm_a * norm_b)
      end
    end
  end
end
