# frozen_string_literal: true

require_relative '../constants'

module RubyGraphRag
  module Parsers
    module NamingUtils
      include RubyGraphRag::Constants

      def singularize_name(name)
        if defined?(ActiveSupport::Inflector)
          ActiveSupport::Inflector.singularize(name)
        else
          naive_singularize(name)
        end
      end

      def classify_name(name)
        if defined?(ActiveSupport::Inflector)
          ActiveSupport::Inflector.camelize(ActiveSupport::Inflector.singularize(name))
        else
          name.split('_').map(&:capitalize).join
        end
      end

      private

      def naive_singularize(name)
        return name.sub(/ies$/, 'y') if name.end_with?('ies')
        return name.sub(/ses$/, 's') if name.end_with?('ses')
        return name.sub(/s$/, '') if name.end_with?('s')

        name
      end

      public

      def resolve_type_name(type_name, owner_qn)
        return nil if type_name.to_s.empty?

        candidates = resolve_constant_owner_candidates(type_name)
        return candidates.first unless candidates.empty?

        owner_parts = owner_qn.split('.')
        while owner_parts.any?
          qn = [*owner_parts[0...-1], type_name.gsub('::', '.')].join('.')
          return qn if type_container?(@function_registry[qn])

          owner_parts.pop
        end

        nil
      end

      def resolve_constant_owner_candidates(receiver)
        normalized = receiver.gsub('::', '.')
        return [normalized] if type_container?(@function_registry[normalized])

        class_entries = @function_registry
                        .select do |qn, type|
                          type_container?(type) && (qn == normalized || qn.end_with?(".#{normalized}"))
                        end
                        .keys
        class_entries.sort_by(&:length)
      end

      def build_scope_qn(module_qn, scope_stack, name)
        parents = scope_stack.select { |s| %i[class module].include?(s[0]) }.map { |s| s[1] }
        [module_qn, parents, name].flatten.reject(&:empty?).join('.')
      end

      def type_container?(type)
        [TYPE_CLASS, TYPE_MODULE].include?(type)
      end

      def constant_name_from_node(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          node.slice.to_s
        else
          node.to_s
        end
      end
    end
  end
end
