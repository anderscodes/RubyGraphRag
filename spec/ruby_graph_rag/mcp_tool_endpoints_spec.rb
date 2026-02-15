# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::MCP::ToolEndpoints do
  it 'indexes repository and supports list/read/query endpoints' do
    repo = make_repo do |r|
      "#{r}app/controllers".mkpath
      "#{r}app/views/users".mkpath
      "#{r}app/controllers/users_controller.rb".write("class UsersController\n  def show\n  end\nend\n")
      "#{r}app/views/users/show.html.erb".write('show')
    end

    mcp = described_class.new
    result = mcp.index_repository(repo_path: repo.to_s)
    expect(result[:status]).to eq('ok')

    list = mcp.list_directory(repo_path: repo.to_s, directory_path: 'app/views/users')
    expect(list).to include('app/views/users/show.html.erb')

    content = mcp.read_file(repo_path: repo.to_s, file_path: 'app/controllers/users_controller.rb')
    expect(content).to include('UsersController')

    summary = mcp.query_code_graph(repo_path: repo.to_s, query: 'summary')
    expect(summary[:status]).to eq('ok')
    expect(summary[:nodes]).to be > 0
  end

  it 'dispatches tools by name' do
    mcp = described_class.new
    expect(mcp.list_tools).to include('index_repository', 'read_file', 'semantic_code_search', 'get_function_source')
    expect { mcp.call_tool('unknown', {}) }.to raise_error(ArgumentError)
  end

  it 'supports semantic search tools after indexing' do
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

    mcp = described_class.new
    mcp.index_repository(repo_path: repo.to_s)

    search = mcp.semantic_code_search(query: 'add two numbers', top_k: 3)
    expect(search[:status]).to eq('ok')
    expect(search[:results]).not_to be_empty

    node_id = search[:results].first[:node_id]
    source = mcp.get_function_source(node_id: node_id)
    expect(source[:status]).to eq('ok')
    expect(source[:source]).to include('a + b')
  end
end
