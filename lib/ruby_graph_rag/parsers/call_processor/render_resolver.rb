# frozen_string_literal: true

module RubyGraphRag
  module Parsers
    module CallProcessorComponents
      module RenderResolver
        private

        def resolve_render_target_from_call(call_node, caller_qn, module_level_caller)
          render_args = extract_render_args(call_node.arguments)
          return nil if render_args.empty?

          return resolve_partial(render_args[:partial], caller_qn, module_level_caller) if render_args[:partial]
          return find_template("app/views/#{render_args[:template]}") if render_args[:template]

          if render_args[:action]
            resource = infer_resource(caller_qn)
            return resource ? find_template("app/views/#{resource}/#{render_args[:action]}") : nil
          end
          if render_args[:symbol]
            resource = infer_resource(caller_qn)
            return resource ? find_template("app/views/#{resource}/#{render_args[:symbol]}") : nil
          end
          if render_args[:string]
            value = render_args[:string]
            return resolve_partial(value, caller_qn, module_level_caller) if value.include?('/') && module_level_caller

            return value.include?('/') ? find_template("app/views/#{value}") : nil
          end

          nil
        end

        def extract_render_args(arguments_node)
          result = {}
          return result unless arguments_node.respond_to?(:arguments)

          arguments_node.arguments.each do |arg|
            case arg
            when Prism::KeywordHashNode
              arg.elements.each do |assoc|
                key = assoc.key
                value = assoc.value
                next unless key.is_a?(Prism::SymbolNode)

                k = key.value.to_s.to_sym
                result[k] = literal_value(value) if %i[partial template action].include?(k)
              end
            when Prism::SymbolNode
              result[:symbol] ||= arg.value.to_s
            when Prism::StringNode
              result[:string] ||= arg.unescaped
            end
          end

          result
        end

        def literal_value(node)
          case node
          when Prism::StringNode
            node.unescaped
          when Prism::SymbolNode
            node.value.to_s
          end
        end

        def resolve_partial(value, caller_qn, module_level_caller)
          if value.include?('/')
            parts = value.split('/')
            name = parts.pop
            return find_template("app/views/#{parts.join('/')}/_#{name}")
          end
          resource = infer_resource(caller_qn)
          if resource.nil? && module_level_caller
            file_path = module_level_caller[2]
            if file_path.start_with?('app/views/')
              pieces = file_path.delete_prefix('app/views/').split('/')
              pieces.pop
              resource = pieces.join('/') unless pieces.empty?
            end
          end
          return nil unless resource

          find_template("app/views/#{resource}/_#{value}")
        end

        def infer_resource(caller_qn)
          parts = caller_qn.split('.')
          idx = parts.index('controllers')
          return nil unless idx

          suffix = parts[(idx + 1)..]
          ctrl = suffix.find { |p| p.end_with?('_controller') }
          return nil unless ctrl

          namespaces = suffix.take_while { |p| p != ctrl }
          [*namespaces, ctrl.sub(/_controller$/, '')].join('/')
        end

        def find_template(base)
          Config.view_extensions.each do |ext|
            candidate = "#{base}#{ext}"
            return candidate if (@repo_path + candidate).exist?
          end
          nil
        end
      end
    end
  end
end
