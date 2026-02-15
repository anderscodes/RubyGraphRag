# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../config'

module RubyGraphRag
  module VectorBackends
    class QdrantBackend
      def initialize
        @collection = RubyGraphRag::Config.qdrant_collection
        @base_url = qdrant_base_url
        raise 'Qdrant URL is not configured' if @base_url.empty?

        @headers = { 'Content-Type' => 'application/json' }
        api_key = RubyGraphRag::Config.qdrant_api_key.to_s.strip
        @headers['api-key'] = api_key unless api_key.empty?

        ensure_collection!
      end

      def store_embedding(node_id:, embedding:, payload:)
        request(
          method: :put,
          path: "/collections/#{escaped_collection}/points",
          body: {
            points: [
              {
                id: node_id,
                vector: embedding,
                payload: payload
              }
            ]
          }
        )
      end

      def search_embeddings(query_embedding:, top_k: nil)
        limit = top_k || RubyGraphRag::Config.semantic_top_k
        response = request(
          method: :post,
          path: "/collections/#{escaped_collection}/points/search",
          body: { vector: query_embedding, limit: limit, with_payload: false }
        )
        response.fetch('result', []).map do |row|
          [row.fetch('id').to_i, row.fetch('score').to_f]
        end
      end

      def payload_for(node_id)
        response = request(
          method: :post,
          path: "/collections/#{escaped_collection}/points",
          body: { ids: [node_id], with_payload: true, with_vector: false }
        )
        response.fetch('result', []).find { |entry| entry.fetch('id').to_i == node_id.to_i }&.[]('payload')
      end

      def clear!
        request(method: :delete, path: "/collections/#{escaped_collection}")
      end

      private

      def ensure_collection!
        response = request(method: :get, path: "/collections/#{escaped_collection}")
        vectors = response.dig('result', 'config', 'params', 'vectors')
        size = extract_vector_size(vectors)
        if size && size != RubyGraphRag::Config.embedding_vector_dim
          raise "Qdrant collection '#{escaped_collection}' has dim #{size}, expected #{RubyGraphRag::Config.embedding_vector_dim}"
        end
      rescue RuntimeError => e
        raise unless e.message.include?('status 404')

        request(
          method: :put,
          path: "/collections/#{escaped_collection}",
          body: { vectors: { size: RubyGraphRag::Config.embedding_vector_dim, distance: 'Cosine' } }
        )
      end

      def request(method:, path:, body: nil)
        uri = URI.join(@base_url, path)
        request =
          case method
          when :get then Net::HTTP::Get.new(uri, @headers)
          when :put then Net::HTTP::Put.new(uri, @headers)
          when :post then Net::HTTP::Post.new(uri, @headers)
          when :delete then Net::HTTP::Delete.new(uri, @headers)
          else
            raise ArgumentError, "Unsupported HTTP method: #{method}"
          end
        request.body = JSON.generate(body) if body

        timeout = RubyGraphRag::Config.embedding_http_timeout.to_i
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: timeout,
          read_timeout: timeout
        ) { |http| http.request(request) }

        status = response.code.to_i
        raise "Qdrant request failed with status #{status}" unless status.between?(200, 299)

        parsed = response.body.to_s.strip
        return {} if parsed.empty?

        JSON.parse(parsed)
      end

      def qdrant_base_url
        base = RubyGraphRag::Config.qdrant_url.to_s.strip
        base.end_with?('/') ? base : "#{base}/"
      end

      def escaped_collection
        URI.encode_www_form_component(@collection)
      end

      def extract_vector_size(vectors_config)
        case vectors_config
        when Hash
          if vectors_config.key?('size')
            vectors_config['size'].to_i
          else
            vectors_config.values.first&.[]('size')&.to_i
          end
        end
      end
    end
  end
end
