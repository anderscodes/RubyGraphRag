# frozen_string_literal: true

require 'pathname'
require_relative '../constants'

module RubyGraphRag
  module Parsers
    class ErbProcessor
      include RubyGraphRag::Constants

      def initialize(repo_path:, project_name:, ingestor:, call_processor:)
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @ingestor = ingestor
        @call_processor = call_processor
      end

      def process_erb_file(file_path)
        file_path = Pathname.new(file_path)
        rel = file_path.relative_path_from(@repo_path).to_s
        source = file_path.read
        code = source.scan(/<%[=-]?\s*(.*?)\s*%>/m).flatten.join("\n")
        return if code.strip.empty?

        @call_processor.process_calls_in_source(
          code,
          [{ qn: rel, name: rel, owner_qn: rel, line: 1 }],
          module_level_caller: [NODE_FILE, 'path', rel]
        )
      end
    end
  end
end
