# frozen_string_literal: true

module RubyGraphRag
  module Services
    module Ingestor
      def ensure_node_batch(_label, _properties)
        raise NotImplementedError
      end

      def ensure_relationship_batch(_from_spec, _rel_type, _to_spec, properties = nil)
        raise NotImplementedError
      end

      def flush_all; end
    end
  end
end
