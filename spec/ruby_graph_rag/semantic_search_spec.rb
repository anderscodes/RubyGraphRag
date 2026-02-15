# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Tools::SemanticSearch do
  it 'returns semantic matches and can fetch source by node id' do
    repo = make_repo do |r|
      "#{r}app/models".mkpath
      "#{r}app/models/calculator.rb".write <<~RUBY
        class Calculator
          def add(a, b)
            a + b
          end
        end
      RUBY
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    RubyGraphRag::GraphUpdater.new(repo_path: repo, ingestor: ingestor).run

    results = described_class.semantic_code_search('add two numbers', top_k: 3)
    expect(results).not_to be_empty
    expect(results.first[:qualified_name]).to include('add')

    source = described_class.get_function_source_code(results.first[:node_id])
    expect(source).to include('a + b')
  end
end
