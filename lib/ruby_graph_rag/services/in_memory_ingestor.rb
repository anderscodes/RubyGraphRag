# frozen_string_literal: true

require_relative 'ingestor'

module RubyGraphRag
  module Services
    class InMemoryIngestor
      include Ingestor

      attr_reader :nodes, :relationships

      def initialize
        @nodes = {}
        @relationships = Set.new
      end

      def ensure_node_batch(label, properties)
        id_key = if properties.key?('qualified_name')
                   'qualified_name'
                 else
                   (properties.key?('path') ? 'path' : 'name')
                 end
        key = [label, id_key, properties[id_key]]
        @nodes[key] = properties.merge('label' => label)
      end

      def ensure_relationship_batch(from_spec, rel_type, to_spec, properties = nil)
        @relationships << [from_spec, rel_type, to_spec, properties]
      end

      def flush_all
        true
      end
    end
  end
end
