# frozen_string_literal: true

require 'dry/configurable'

module RubyGraphRag
  module Config
    extend Dry::Configurable

    setting :view_extensions, default: ['.html.erb', '.html.haml', '.html.slim'].freeze
    setting :controller_dir, default: 'app/controllers'
    setting :views_dir, default: 'app/views'
    setting :ruby_extensions, default: ['.rb'].freeze
    setting :semantic_enabled, default: true
    setting :embedding_vector_dim, default: 768
    setting :embedding_max_length, default: 512
    setting :semantic_backend, default: 'qdrant'
    setting :embedding_backend, default: 'local_hash'
    setting :embedding_model, default: 'text-embedding-3-small'
    setting :openai_base_url, default: 'https://api.openai.com/v1'
    setting :openai_api_key, default: nil
    setting :embedding_http_timeout, default: 30
    setting :semantic_top_k, default: 5
    setting :semantic_store_path, default: '.ruby_graph_rag_embeddings.pstore'
    setting :qdrant_url, default: 'http://127.0.0.1:6333'
    setting :qdrant_api_key, default: nil
    setting :qdrant_collection, default: 'ruby_graph_rag_embeddings'

    SETTING_NAMES = %i[
      view_extensions controller_dir views_dir ruby_extensions
      semantic_enabled embedding_vector_dim embedding_max_length
      semantic_backend embedding_backend embedding_model openai_base_url
      embedding_http_timeout semantic_top_k semantic_store_path
      qdrant_url qdrant_api_key qdrant_collection
    ].freeze

    class << self
      SETTING_NAMES.each do |name|
        define_method(name) { config.public_send(name) }
      end

      def openai_api_key
        config.openai_api_key || ENV.fetch('OPENAI_API_KEY', '')
      end

      def reset!
        @config = config.pristine
      end
    end
  end
end
