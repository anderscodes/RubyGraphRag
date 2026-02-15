# frozen_string_literal: true

require 'pathname'
require 'prism'
require_relative '../constants'
require_relative '../config'
require_relative 'naming_utils'

module RubyGraphRag
  module Parsers
    class RailsAssociationProcessor
      include RubyGraphRag::Constants
      include NamingUtils

      ASSOCIATION_MACROS = %w[has_many has_one belongs_to has_and_belongs_to_many].freeze

      def initialize(repo_path:, project_name:, function_registry:, association_registry:)
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @function_registry = function_registry
        @association_registry = association_registry
      end

      def process
        models_dir = @repo_path.join('app', 'models')
        return unless models_dir.directory?

        models_dir.glob('**/*.rb').each do |path|
          process_model_file(path)
        end
      end

      private

      def process_model_file(path)
        rel = path.relative_path_from(@repo_path)
        module_qn = [@project_name, rel.sub_ext('').each_filename.to_a].flatten.join('.')

        source = path.read
        parsed = Prism.parse(source)
        return if parsed.errors.any?

        walk_for_associations(parsed.value, module_qn, [])
      end

      def walk_for_associations(node, module_qn, scope_stack)
        return unless node

        case node
        when Prism::ClassNode
          class_name = constant_name_from_node(node.constant_path).gsub('::', '.')
          class_qn = build_scope_qn(module_qn, scope_stack, class_name)
          new_scope = scope_stack + [[:class, class_name, class_qn]]
          walk_association_body(node.body, module_qn, new_scope)

        when Prism::ModuleNode
          mod_name = constant_name_from_node(node.constant_path).gsub('::', '.')
          mod_qn = build_scope_qn(module_qn, scope_stack, mod_name)
          new_scope = scope_stack + [[:module, mod_name, mod_qn]]
          walk_association_body(node.body, module_qn, new_scope)

        when Prism::CallNode
          process_association_call(node, scope_stack)

        else
          walk_association_children(node, module_qn, scope_stack)
        end
      end

      def walk_association_body(body_node, module_qn, scope_stack)
        return unless body_node

        case body_node
        when Prism::StatementsNode
          body_node.body.each { |child| walk_for_associations(child, module_qn, scope_stack) }
        else
          walk_for_associations(body_node, module_qn, scope_stack)
        end
      end

      def walk_association_children(node, module_qn, scope_stack)
        return unless node.respond_to?(:child_nodes)

        node.child_nodes.each do |child|
          walk_for_associations(child, module_qn, scope_stack) if child
        end
      end

      def process_association_call(call_node, scope_stack)
        macro = call_node.name.to_s
        return unless ASSOCIATION_MACROS.include?(macro)

        owner = scope_stack.reverse.find { |entry| entry[0] == :class }
        return unless owner

        owner_qn = owner[2]
        args = call_node.arguments&.arguments
        return unless args&.any?

        first_arg = args.first
        return unless first_arg.is_a?(Prism::SymbolNode)

        association_name = first_arg.value.to_s
        class_name = extract_class_name_option(args)
        target_qn = resolve_association_target(owner_qn, macro, association_name, class_name)
        return unless target_qn

        @association_registry[owner_qn][association_name] ||= []
        @association_registry[owner_qn][association_name] << target_qn
        @association_registry[owner_qn][association_name].uniq!
      end

      def extract_class_name_option(args)
        args.each do |arg|
          next unless arg.is_a?(Prism::KeywordHashNode)

          arg.elements.each do |assoc|
            next unless assoc.is_a?(Prism::AssocNode)

            key = assoc.key
            next unless key.is_a?(Prism::SymbolNode) && key.value == 'class_name'

            value = assoc.value
            case value
            when Prism::StringNode
              return value.unescaped
            when Prism::SymbolNode
              return value.value.to_s
            end
          end
        end
        nil
      end

      def resolve_association_target(owner_qn, macro, association_name, class_name)
        type_name = if class_name
                      class_name
                    elsif %w[has_many has_and_belongs_to_many].include?(macro)
                      singularize_name(association_name).split('_').map(&:capitalize).join
                    else
                      association_name.split('_').map(&:capitalize).join
                    end

        resolve_type_name(type_name, owner_qn)
      end
    end
  end
end
