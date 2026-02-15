# frozen_string_literal: true

require 'prism'

module RubyGraphRag
  module Parsers
    module DefinitionWalker
      include RubyGraphRag::Constants
      include NamingUtils

      private

      def walk_definitions(node, module_qn, rel, scope_stack, methods)
        return unless node

        case node
        when Prism::ClassNode
          class_name = constant_name_from_node(node.constant_path)
          lineno = node.location.start_line
          class_qn = build_scope_qn(module_qn, scope_stack, class_name.gsub('::', '.'))
          new_scope = scope_stack + [[:class, class_name.gsub('::', '.'), class_qn]]

          @function_registry[class_qn] = TYPE_CLASS
          @simple_name_lookup[class_name.split('::').last] << class_qn
          @ingestor.ensure_node_batch(
            NODE_CLASS,
            {
              'qualified_name' => class_qn,
              'name' => class_name,
              'path' => rel,
              'start_line' => lineno,
              'kind' => 'class'
            }
          )
          @ingestor.ensure_relationship_batch([NODE_MODULE, 'qualified_name', module_qn], REL_DEFINES,
                                              [NODE_CLASS, 'qualified_name', class_qn])

          if node.superclass
            parent = constant_name_from_node(node.superclass)
            parent_qn = [module_qn, parent.gsub('::', '.')].join('.')
            @ingestor.ensure_relationship_batch([NODE_CLASS, 'qualified_name', class_qn], REL_INHERITS,
                                                [NODE_CLASS, 'qualified_name', parent_qn])
          end

          walk_body(node.body, module_qn, rel, new_scope, methods)

        when Prism::ModuleNode
          mod_name = constant_name_from_node(node.constant_path)
          lineno = node.location.start_line
          mod_qn = build_scope_qn(module_qn, scope_stack, mod_name.gsub('::', '.'))
          new_scope = scope_stack + [[:module, mod_name.gsub('::', '.'), mod_qn]]

          @function_registry[mod_qn] = TYPE_MODULE
          @simple_name_lookup[mod_name.split('::').last] << mod_qn
          @ingestor.ensure_node_batch(
            NODE_CLASS,
            {
              'qualified_name' => mod_qn,
              'name' => mod_name,
              'path' => rel,
              'start_line' => lineno,
              'kind' => 'module'
            }
          )
          @ingestor.ensure_relationship_batch([NODE_MODULE, 'qualified_name', module_qn], REL_DEFINES,
                                              [NODE_CLASS, 'qualified_name', mod_qn])

          walk_body(node.body, module_qn, rel, new_scope, methods)

        when Prism::DefNode
          method_name = node.name.to_s
          owner = scope_stack.reverse.find { |s| %i[class module].include?(s[0]) }
          return unless owner

          lineno = node.location.start_line
          end_line = node.location.end_line
          method_qn = [owner[2], method_name].join('.')
          methods << { qn: method_qn, name: method_name, owner_qn: owner[2], line: lineno }

          props = {
            'qualified_name' => method_qn,
            'name' => method_name,
            'start_line' => lineno,
            'end_line' => end_line
          }
          @function_registry[method_qn] = TYPE_METHOD
          @simple_name_lookup[method_name] << method_qn
          @ingestor.ensure_node_batch(NODE_FUNCTION, props)
          @ingestor.ensure_relationship_batch([NODE_CLASS, 'qualified_name', owner[2]], REL_DEFINES,
                                              [NODE_FUNCTION, 'qualified_name', method_qn])

        when Prism::SingletonClassNode
          walk_body(node.body, module_qn, rel, scope_stack, methods)

        else
          walk_children(node, module_qn, rel, scope_stack, methods)
        end
      end

      def walk_body(body_node, module_qn, rel, scope_stack, methods)
        return unless body_node

        case body_node
        when Prism::StatementsNode
          body_node.body.each { |child| walk_definitions(child, module_qn, rel, scope_stack, methods) }
        else
          walk_definitions(body_node, module_qn, rel, scope_stack, methods)
        end
      end

      def walk_children(node, module_qn, rel, scope_stack, methods)
        return unless node.respond_to?(:child_nodes)

        node.child_nodes.each do |child|
          walk_definitions(child, module_qn, rel, scope_stack, methods) if child
        end
      end
    end
  end
end
