# frozen_string_literal: true

require 'pathname'
require_relative '../constants'
require_relative '../config'

module RubyGraphRag
  module Parsers
    class RailsConventionProcessor
      include RubyGraphRag::Constants

      def initialize(repo_path:, project_name:, ingestor:, function_registry:)
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @ingestor = ingestor
        @function_registry = function_registry
      end

      def process
        views = @repo_path + Config.controller_dir.sub('controllers', 'views')
        controllers = @repo_path + Config.controller_dir
        return unless views.directory? && controllers.directory?

        template_map = build_template_map(views)
        @function_registry.each do |qn, type|
          next unless type == TYPE_METHOD

          resource, action = parse_controller_action(qn)
          next unless resource && action

          key = "#{resource}/#{action}"
          rel_path = template_map[key]
          next unless rel_path

          @ingestor.ensure_relationship_batch([NODE_FUNCTION, 'qualified_name', qn], REL_RENDERS,
                                              [NODE_FILE, 'path', rel_path])
        end
      end

      private

      def build_template_map(views)
        map = {}
        views.glob('**/*').each do |path|
          next unless path.file?
          next if path.basename.to_s.start_with?('_')

          ext = Config.view_extensions.find { |v| path.to_s.end_with?(v) }
          next unless ext

          action = path.basename.to_s.delete_suffix(ext)
          key = "#{path.parent.relative_path_from(views)}/#{action}"
          map[key] = path.relative_path_from(@repo_path).to_s
        end
        map
      end

      def parse_controller_action(qualified_name)
        parts = qualified_name.split('.')
        idx = parts.index('controllers')
        return [nil, nil] unless idx

        suffix = parts[(idx + 1)..]
        ctrl_idx = suffix.index { |p| p.end_with?('_controller') }
        return [nil, nil] unless ctrl_idx && suffix.length > ctrl_idx + 1

        namespaces = suffix[0...ctrl_idx]
        resource = suffix[ctrl_idx].sub(/_controller$/, '')
        action = suffix.last
        [[*namespaces, resource].join('/'), action]
      end
    end
  end
end
