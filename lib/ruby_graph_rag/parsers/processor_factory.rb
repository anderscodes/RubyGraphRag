# frozen_string_literal: true

require_relative 'structure_processor'
require_relative 'definition_processor'
require_relative 'call_processor'
require_relative 'rails_convention_processor'
require_relative 'rails_association_processor'
require_relative 'erb_processor'

module RubyGraphRag
  module Parsers
    class ProcessorFactory
      attr_reader :repo_path, :project_name, :ingestor, :function_registry, :simple_name_lookup, :association_registry

      def initialize(repo_path:, project_name:, ingestor:, function_registry:, simple_name_lookup:,
                     association_registry:)
        @repo_path = repo_path
        @project_name = project_name
        @ingestor = ingestor
        @function_registry = function_registry
        @simple_name_lookup = simple_name_lookup
        @association_registry = association_registry
      end

      def structure_processor
        @structure_processor ||= StructureProcessor.new(repo_path: repo_path, project_name: project_name,
                                                        ingestor: ingestor)
      end

      def definition_processor
        @definition_processor ||= DefinitionProcessor.new(
          repo_path: repo_path,
          project_name: project_name,
          ingestor: ingestor,
          function_registry: function_registry,
          simple_name_lookup: simple_name_lookup
        )
      end

      def call_processor
        @call_processor ||= CallProcessor.new(
          repo_path: repo_path,
          project_name: project_name,
          ingestor: ingestor,
          function_registry: function_registry,
          simple_name_lookup: simple_name_lookup,
          association_registry: association_registry
        )
      end

      def rails_association_processor
        @rails_association_processor ||= RailsAssociationProcessor.new(
          repo_path: repo_path,
          project_name: project_name,
          function_registry: function_registry,
          association_registry: association_registry
        )
      end

      def rails_convention_processor
        @rails_convention_processor ||= RailsConventionProcessor.new(
          repo_path: repo_path,
          project_name: project_name,
          ingestor: ingestor,
          function_registry: function_registry
        )
      end

      def erb_processor
        @erb_processor ||= ErbProcessor.new(
          repo_path: repo_path,
          project_name: project_name,
          ingestor: ingestor,
          call_processor: call_processor
        )
      end
    end
  end
end
