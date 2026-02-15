# frozen_string_literal: true

require 'prism'

module RubyGraphRag
  module Parsers
    module CallProcessorComponents
      module MethodBodyParser
        def parse_method_body_as_program(body)
          return nil if body.strip.empty?

          source = body.dup
          parsed = Prism.parse(source)
          while parsed.errors.any?
            lines = source.lines
            break if lines.empty? || lines.last.strip != 'end'

            lines.pop
            source = lines.join
            parsed = Prism.parse(source)
          end
          return nil if parsed.errors.any?

          program = parsed.value
          statements = program.statements&.body || []
          if statements.length == 1 && statements.first.is_a?(Prism::DefNode)
            inner = statements.first.body
            return Prism.parse(inner&.slice || '').value
          end
          program
        end

        def each_call_node(program, &block)
          each_node(program) do |node|
            block.call(node) if node.is_a?(Prism::CallNode)
          end
        end

        def each_node(node, &block)
          return unless node

          block.call(node)
          return unless node.respond_to?(:child_nodes)

          node.child_nodes.each { |child| each_node(child, &block) }
        end
      end
    end
  end
end
