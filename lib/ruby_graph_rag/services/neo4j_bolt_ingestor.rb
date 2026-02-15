# frozen_string_literal: true

require_relative 'ingestor'

module RubyGraphRag
  module Services
    class Neo4jBoltIngestor
      include Ingestor

      attr_reader :driver

      def initialize(url: 'bolt://127.0.0.1:7688', username: '', password: '', driver: nil)
        @driver = driver || self.class.build_driver(url: url, username: username, password: password)
      end

      def self.build_driver(url:, username:, password:)
        require 'neo4j/driver'

        auth = if username.to_s.empty? && password.to_s.empty?
                  Neo4j::Driver::AuthTokens.basic('neo4j', 'localdevpassword')
                else
                 Neo4j::Driver::AuthTokens.basic(username.to_s, password.to_s)
               end
        Neo4j::Driver::GraphDatabase.driver(url, auth)
      end

      def ensure_node_batch(label, properties)
        id_key = infer_id_key(properties)
        query = <<~CYPHER
          MERGE (n:#{safe_token(label)} {#{safe_token(id_key)}: $id})
          SET n += $props
        CYPHER
        props = properties.dup
        id_value = props.delete(id_key)
        execute_write(query, { id: id_value, props: props })
      end

      def ensure_relationship_batch(from_spec, rel_type, to_spec, properties = nil)
        from_label, from_key, from_val = from_spec
        to_label, to_key, to_val = to_spec
        query = <<~CYPHER
          MATCH (a:#{safe_token(from_label)} {#{safe_token(from_key)}: $from_val})
          MATCH (b:#{safe_token(to_label)} {#{safe_token(to_key)}: $to_val})
          MERGE (a)-[r:#{safe_token(rel_type)}]->(b)
          SET r += $props
        CYPHER
        execute_write(query, { from_val: from_val, to_val: to_val, props: properties || {} })
      end

      def execute_write(query, params = nil)
        session = @driver.session
        session.write_transaction { |tx| tx.run(query, **(params || {})) }
      ensure
        session&.close
      end

      def fetch_all(query, params = nil)
        session = @driver.session
        records = session.read_transaction { |tx| tx.run(query, **(params || {})).to_a }
        records.map do |record|
          if record.respond_to?(:to_h)
            record.to_h
          elsif record.respond_to?(:keys)
            record.keys.to_h { |k| [k, record[k]] }
          else
            {}
          end
        end
      ensure
        session&.close
      end

      def flush_all
        true
      end

      def close
        @driver&.close
      end

      private

      def infer_id_key(properties)
        return 'qualified_name' if properties.key?('qualified_name')
        return 'path' if properties.key?('path')

        'name'
      end

      def safe_token(token)
        token_str = token.to_s
        raise ArgumentError, "Unsafe token: #{token_str.inspect}" unless token_str.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)

        token_str
      end
    end
  end
end
