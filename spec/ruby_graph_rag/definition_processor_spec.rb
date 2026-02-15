# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Parsers::DefinitionProcessor do
  it 'parses classes, methods, and inheritance' do
    repo = make_repo do |r|
      "#{r}app/models".mkpath
      "#{r}app/models/user.rb".write <<~RUBY
        class User < ApplicationRecord
          def full_name
            name
          end

          def self.create_from(email)
            new(email: email)
          end
        end
      RUBY
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {}
    lookup = Hash.new { |h, k| h[k] = Set.new }

    processor = described_class.new(
      repo_path: repo,
      project_name: repo.basename.to_s,
      ingestor: ingestor,
      function_registry: registry,
      simple_name_lookup: lookup
    )

    parsed = processor.process_file("#{repo}app/models/user.rb")
    expect(parsed).not_to be_nil

    class_nodes = ingestor.nodes.values.select { |n| n['label'] == 'Class' }
    expect(class_nodes.map { |n| n['qualified_name'] }.join(' ')).to include('User')

    function_nodes = ingestor.nodes.values.select { |n| n['label'] == 'Function' }
    expect(function_nodes.map { |n| n['name'] }).to include('full_name', 'create_from')

    inherits = ingestor.relationships.select { |r| r[1] == 'INHERITS' }
    expect(inherits.length).to eq(1)
  end
end
