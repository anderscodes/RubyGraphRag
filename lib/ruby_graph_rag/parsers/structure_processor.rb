# frozen_string_literal: true

require 'pathname'
require_relative '../constants'

module RubyGraphRag
  module Parsers
    class StructureProcessor
      include RubyGraphRag::Constants

      attr_reader :structural_elements

      def initialize(repo_path:, project_name:, ingestor:)
        @repo_path = Pathname.new(repo_path)
        @project_name = project_name
        @ingestor = ingestor
        @structural_elements = {}
      end

      def identify_structure
        @ingestor.ensure_node_batch(NODE_PROJECT, { 'name' => @project_name })
        @repo_path.glob('**/*').select(&:directory?).sort.each do |dir|
          rel = dir.relative_path_from(@repo_path).to_s
          next if rel == '.'

          @ingestor.ensure_node_batch(NODE_FOLDER, { 'path' => rel, 'name' => dir.basename.to_s })
          parent = if dir.parent == @repo_path
                     [NODE_PROJECT, 'name',
                      @project_name]
                   else
                     [NODE_FOLDER, 'path',
                      dir.parent.relative_path_from(@repo_path).to_s]
                   end
          @ingestor.ensure_relationship_batch(parent, REL_CONTAINS_FOLDER, [NODE_FOLDER, 'path', rel])
        end
      end

      def process_generic_file(file_path)
        rel = file_path.relative_path_from(@repo_path).to_s
        parent_dir = if file_path.parent == @repo_path
                       [NODE_PROJECT, 'name',
                        @project_name]
                     else
                       [NODE_FOLDER, 'path',
                        file_path.parent.relative_path_from(@repo_path).to_s]
                     end
        @ingestor.ensure_node_batch(NODE_FILE,
                                    { 'path' => rel, 'name' => file_path.basename.to_s,
                                      'extension' => file_path.extname })
        @ingestor.ensure_relationship_batch(parent_dir, REL_CONTAINS_FILE, [NODE_FILE, 'path', rel])
      end
    end
  end
end
