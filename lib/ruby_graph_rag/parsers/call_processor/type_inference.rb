# frozen_string_literal: true

module RubyGraphRag
  module Parsers
    module CallProcessorComponents
      module TypeInference
        include RubyGraphRag::Constants
        include NamingUtils

        private

        def infer_types_from_ast(program, method)
          ivar_types = {}
          local_types = {}
          owner_short = method[:owner_qn].split('.').last

          each_node(program) do |node|
            if node.is_a?(Prism::LocalVariableWriteNode)
              resolved = infer_expression_types(
                node.value,
                owner_qn: method[:owner_qn],
                owner_short: owner_short,
                ivar_types: ivar_types,
                local_types: local_types
              )
              local_types[node.name.to_s] = resolved unless resolved.empty?
            elsif node.is_a?(Prism::InstanceVariableWriteNode)
              resolved = infer_expression_types(
                node.value,
                owner_qn: method[:owner_qn],
                owner_short: owner_short,
                ivar_types: ivar_types,
                local_types: local_types
              )
              ivar_types[node.name.to_s] = resolved unless resolved.empty?
            end
          end

          [ivar_types, local_types]
        end

        def infer_expression_types(node, owner_qn:, owner_short:, ivar_types:, local_types:)
          return [] unless node

          case node
          when Prism::SelfNode
            [owner_qn]
          when Prism::InstanceVariableReadNode
            ivar_types[node.name.to_s] || []
          when Prism::LocalVariableReadNode
            local_types[node.name.to_s] || []
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            resolve_constant_owner_candidates(node.slice.to_s)
          when Prism::CallNode
            infer_call_result_types(
              node,
              owner_qn: owner_qn,
              owner_short: owner_short,
              ivar_types: ivar_types,
              local_types: local_types
            )
          else
            []
          end
        end

        def infer_call_result_types(call_node, owner_qn:, owner_short:, ivar_types:, local_types:)
          name = call_node.name.to_s
          return [] if name.empty?

          if name == 'new'
            receiver = call_node.receiver
            return [resolve_type_name(owner_short, owner_qn)].compact if receiver.nil?

            type_name = normalize_receiver(receiver)
            return [resolve_type_name(type_name, owner_qn)].compact
          end

          receiver_types = infer_expression_types(
            call_node.receiver,
            owner_qn: owner_qn,
            owner_short: owner_short,
            ivar_types: ivar_types,
            local_types: local_types
          )
          return [] if receiver_types.empty?

          result_types = []
          receiver_types.each do |receiver_type|
            result_types.concat(resolve_association_result_types(receiver_type, name))
            if association_builder_method?(name)
              association_name = association_name_for_builder(name)
              result_types.concat(resolve_association_result_types(receiver_type, association_name)) if association_name
            end
            result_types << receiver_type if constructor_like_method?(name) || relation_passthrough_method?(name)
            result_types << receiver_type if method_defined_on_receiver?(receiver_type, name)
          end

          result_types.uniq
        end

        def resolve_association_result_types(receiver_type, association_name)
          return [] if association_name.to_s.empty?

          associations = @association_registry[receiver_type]
          direct = associations && associations[association_name]
          return direct if direct&.any?
          return [] if associations && !associations.empty?
          return [] unless association_name.match?(/\A[a-z_]+\z/)

          fallback = resolve_type_name(classify_name(singularize_name(association_name)), receiver_type)
          fallback ? [fallback] : []
        end

        def association_builder_method?(name)
          name.start_with?('build_') || name.start_with?('create_')
        end

        def association_name_for_builder(name)
          return nil unless association_builder_method?(name)

          name.sub(/\A(build_|create_)/, '').delete_suffix('!')
        end

        def constructor_like_method?(name)
          RubyGraphRag::Parsers::CallProcessor::CONSTRUCTOR_LIKE_METHODS.include?(name)
        end

        def relation_passthrough_method?(name)
          RubyGraphRag::Parsers::CallProcessor::RELATION_PASSTHROUGH_METHODS.include?(name)
        end

        def method_defined_on_receiver?(receiver_type, name)
          function_exists?("#{receiver_type}.#{name}")
        end

        def function_exists?(qualified_name)
          @function_registry[qualified_name] == TYPE_METHOD
        end

        def prefix_score(owner_qn, candidate_qn)
          owner_parts = owner_qn.split('.')
          cand_parts = candidate_qn.split('.')
          score = 0
          owner_parts.zip(cand_parts).each do |a, b|
            break unless a == b

            score += 1
          end
          score
        end

        def normalize_receiver(receiver_node)
          return nil if receiver_node.nil?

          case receiver_node
          when Prism::SelfNode
            'self'
          when Prism::InstanceVariableReadNode, Prism::LocalVariableReadNode
            receiver_node.name.to_s
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            receiver_node.slice.to_s
          end
        end
      end
    end
  end
end
