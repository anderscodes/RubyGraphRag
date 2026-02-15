# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe RubyGraphRag::CLI do
  it 'indexes a repository with in_memory backend' do
    repo = make_repo do |r|
      "#{r}app/controllers".mkpath
      "#{r}app/views/users".mkpath
      "#{r}app/controllers/users_controller.rb".write("class UsersController\n  def show\n  end\nend\n")
      "#{r}app/views/users/show.html.erb".write('show')
    end

    output = StringIO.new
    $stdout = output
    described_class.start(['index', repo.to_s, '--backend', 'in_memory'])
    $stdout = STDOUT

    payload = JSON.parse(output.string)
    expect(payload['status']).to eq('ok')
    expect(payload['nodes']).to be > 0
  end

  it 'runs semantic search after indexing' do
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

    output = StringIO.new
    $stdout = output
    described_class.start(['index', repo.to_s, '--backend', 'in_memory'])
    output.truncate(0)
    output.rewind
    described_class.start(['semantic_search', 'add two numbers', '--top-k', '3'])
    $stdout = STDOUT

    payload = JSON.parse(output.string)
    expect(payload['status']).to eq('ok')
    expect(payload['results']).not_to be_empty
  end
end
