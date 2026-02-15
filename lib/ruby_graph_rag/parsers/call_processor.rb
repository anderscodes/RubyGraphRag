# frozen_string_literal: true

require 'pathname'
require 'prism'
require_relative '../constants'
require_relative '../config'
require_relative 'naming_utils'
require_relative 'call_processor/method_body_parser'
require_relative 'call_processor/type_inference'
require_relative 'call_processor/render_resolver'

module RubyGraphRag
  module Parsers
    class CallProcessor
      include RubyGraphRag::Constants
      include NamingUtils
      include CallProcessorComponents::MethodBodyParser
      include CallProcessorComponents::TypeInference
      include CallProcessorComponents::RenderResolver

      CONSTRUCTOR_LIKE_METHODS = %w[
        new
        build
        create
        create!
        first_or_create
        first_or_create!
        first_or_initialize
        find_or_create_by
        find_or_create_by!
        find_or_initialize_by
        create_or_find_by
        create_or_find_by!
        find_by
        find_by!
        find
        first
        first!
        last
        last!
        take
        take!
        sole
      ].freeze
      RELATION_PASSTHROUGH_METHODS = %w[
        where
        order
        reorder
        rewhere
        joins
        left_joins
        includes
        preload
        eager_load
        references
        select
        limit
        offset
        group
        having
        merge
        none
        readonly
        lock
        distinct
      ].freeze

      def initialize(repo_path:, project_name:, ingestor:, function_registry:, simple_name_lookup:,
                     association_registry: {})
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @ingestor = ingestor
        @function_registry = function_registry
        @simple_name_lookup = simple_name_lookup
        @association_registry = association_registry
      end

      def process_calls_in_file(parsed_file, module_level_caller: nil)
        process_calls_in_source(parsed_file.text, parsed_file.method_defs, module_level_caller: module_level_caller)
      end

      def process_calls_in_source(source, method_defs, module_level_caller: nil)
        lines = source.lines
        method_defs.each_with_index do |m, idx|
          from = [NODE_FUNCTION, 'qualified_name', m[:qn]]
          body_start = m[:line]
          body_end = idx + 1 < method_defs.length ? method_defs[idx + 1][:line] - 1 : lines.length
          body = lines[(body_start - 1)...body_end]&.join.to_s
          ast_root = parse_method_body_as_program(body)
          next unless ast_root

          ivar_types, local_types = infer_types_from_ast(ast_root, m)

          each_call_node(ast_root) do |call_node|
            name = call_node.name.to_s
            next if name.empty? || RUBY_RESERVED.include?(name)

            if name == 'render'
              target = resolve_render_target_from_call(call_node, m[:qn], module_level_caller)
              next unless target

              caller = module_level_caller || from
              @ingestor.ensure_relationship_batch(caller, REL_RENDERS, [NODE_FILE, 'path', target])
              next
            end

            resolve_call_target(
              name,
              owner_qn: m[:owner_qn],
              owner_short: m[:owner_qn].split('.').last,
              receiver_node: call_node.receiver,
              ivar_types: ivar_types,
              local_types: local_types
            ).each do |target_qn|
              @ingestor.ensure_relationship_batch(from, REL_CALLS, [NODE_FUNCTION, 'qualified_name', target_qn])
            end
          end
        end
      end

      private

      def resolve_call_target(name, owner_qn:, owner_short:, receiver_node:, ivar_types:, local_types:)
        if receiver_node
          receiver_types = infer_expression_types(
            receiver_node,
            owner_qn: owner_qn,
            owner_short: owner_short,
            ivar_types: ivar_types,
            local_types: local_types
          )
          resolve_receiver_call(receiver_types, name)
        else
          resolve_bare_call(name, owner_qn)
        end
      end

      def resolve_receiver_call(owner_candidates, name)
        owner_candidates.uniq.filter_map do |owner|
          qn = "#{owner}.#{name}"
          qn if function_exists?(qn)
        end
      end

      def resolve_bare_call(name, owner_qn)
        same_owner = "#{owner_qn}.#{name}"
        return [same_owner] if function_exists?(same_owner)

        matches = @simple_name_lookup[name].to_a
        return [] if matches.empty?
        return matches if matches.length == 1

        ranked = matches
                 .map { |qn| [qn, prefix_score(owner_qn, qn)] }
                 .sort_by { |(_, score)| -score }
        best = ranked.first[1]
        ranked.select { |(_, score)| score == best }.map(&:first)
      end
    end
  end
end
