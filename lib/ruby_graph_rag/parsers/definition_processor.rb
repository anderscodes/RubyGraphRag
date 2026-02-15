# frozen_string_literal: true

require 'pathname'
require 'prism'
require_relative '../constants'
require_relative 'naming_utils'
require_relative 'definition_processor/walker'

module RubyGraphRag
  module Parsers
    ParsedFile = Struct.new(:path, :module_qn, :text, :method_defs, keyword_init: true) do
      def initialize(**kwargs)
        kwargs[:method_defs] ||= kwargs.delete(:methods)
        super
      end

      def methods
        method_defs
      end

      def methods=(value)
        self.method_defs = value
      end
    end

    class DefinitionProcessor
      include RubyGraphRag::Constants
      include NamingUtils
      include DefinitionWalker

      def initialize(repo_path:, project_name:, ingestor:, function_registry:, simple_name_lookup:)
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @ingestor = ingestor
        @function_registry = function_registry
        @simple_name_lookup = simple_name_lookup
      end

      def process_file(file_path)
        file_path = Pathname.new(file_path)
        return nil unless file_path.extname == '.rb'

        rel = file_path.relative_path_from(@repo_path)
        module_qn = [@project_name, rel.sub_ext('').each_filename.to_a].flatten.join('.')
        @ingestor.ensure_node_batch(NODE_MODULE,
                                    { 'qualified_name' => module_qn, 'name' => file_path.basename.to_s,
                                      'path' => rel.to_s })
        @ingestor.ensure_relationship_batch([NODE_FILE, 'path', rel.to_s], REL_CONTAINS_MODULE,
                                            [NODE_MODULE, 'qualified_name', module_qn])

        source = file_path.read
        parsed = Prism.parse(source)
        if parsed.errors.any?
          return ParsedFile.new(
            path: file_path,
            module_qn: module_qn,
            text: source,
            method_defs: []
          )
        end

        methods = []
        walk_definitions(parsed.value, module_qn, rel.to_s, [], methods)

        ParsedFile.new(path: file_path, module_qn: module_qn, text: source, method_defs: methods)
      end
    end
  end
end
