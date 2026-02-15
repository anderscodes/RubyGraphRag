# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'zlib'
require_relative 'config'

module RubyGraphRag
  module Embedder
    class << self
      def embed_code(code, max_length: nil, vector_dim: nil)
        raise RubyGraphRag::EmbeddingError, 'Semantic search is disabled' unless Config.semantic_enabled

        limit = max_length || Config.embedding_max_length
        backend = Config.embedding_backend.to_s

        if backend == 'openai'
          model_embed_code(code.to_s, limit)
        else
          local_embed_code(code.to_s, limit, vector_dim || Config.embedding_vector_dim)
        end
      end

      private

      def model_embed_code(code, limit)
        api_key = Config.openai_api_key.to_s.strip
        raise RubyGraphRag::EmbeddingError, 'OPENAI_API_KEY is required for openai embedding backend' if api_key.empty?

        base = Config.openai_base_url.to_s.sub(%r{/\z}, '')
        uri = URI.parse("#{base}/embeddings")
        timeout = Config.embedding_http_timeout.to_i

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{api_key}"
        request.body = JSON.generate(
          {
            model: Config.embedding_model.to_s,
            input: truncate_for_model(code, limit)
          }
        )

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: timeout,
          read_timeout: timeout
        ) { |http| http.request(request) }

        status = response.code.to_i
        unless status.between?(200, 299)
          raise RubyGraphRag::EmbeddingError, "Embedding API request failed with status #{status}"
        end

        body = JSON.parse(response.body)
        embedding = body.fetch('data').first.fetch('embedding')
        embedding.map(&:to_f)
      end

      def local_embed_code(code, limit, dim)
        tokens = tokenize(code, limit)
        vector = Array.new(dim, 0.0)

        tokens.each do |token|
          primary = Zlib.crc32(token) % dim
          weight = token.match?(%r{[+\-*/]}) ? 3.0 : 1.0
          vector[primary] += weight
        end

        normalize(vector)
      end

      def tokenize(code, limit)
        code.to_s.downcase.scan(%r{[a-z_][a-z0-9_!?=]*|[+\-*/]}).first(limit)
      end

      def truncate_for_model(code, limit)
        code.split(/\s+/).first(limit).join(' ')
      end

      def normalize(vector)
        norm = Math.sqrt(vector.sum { |v| v * v })
        return vector if norm.zero?

        vector.map { |v| v / norm }
      end
    end
  end
end
