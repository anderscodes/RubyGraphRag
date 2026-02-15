# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::GraphUpdater do
  it 'runs full pipeline for a rails-style ruby repo' do
    repo = make_repo do |r|
      "#{r}app/controllers".mkpath
      "#{r}app/views/users".mkpath
      "#{r}app/views/shared".mkpath
      "#{r}app/controllers/users_controller.rb".write <<~RUBY
        class UsersController < ApplicationController
          def show
            render partial: "shared/nav"
          end
        end
      RUBY
      "#{r}app/views/users/show.html.erb".write("<%= render partial: 'shared/nav' %>")
      "#{r}app/views/shared/_nav.html.erb".write('<nav>n</nav>')
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    updater = described_class.new(repo_path: repo, ingestor: ingestor)
    updater.run

    expect(ingestor.nodes.values.any? { |n| n['label'] == 'Project' }).to eq(true)
    expect(ingestor.nodes.values.any? do |n|
      n['label'] == 'Class' && n['name'].include?('UsersController')
    end).to eq(true)

    renders = ingestor.relationships.select { |r| r[1] == 'RENDERS' }
    expect(renders.map { |r| r[2][2] }).to include('app/views/shared/_nav.html.erb')

    semantic_hits = RubyGraphRag::Tools::SemanticSearch.semantic_code_search('show user', top_k: 1)
    expect(semantic_hits.length).to eq(1)
  end

  it 'captures ruby inheritance relationships' do
    repo = make_repo do |r|
      "#{r}app/models".mkpath
      "#{r}app/models/animal.rb".write <<~RUBY
        class Animal
        end

        class Dog < Animal
        end
      RUBY
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    described_class.new(repo_path: repo, ingestor: ingestor).run

    inherits = ingestor.relationships.select { |r| r[1] == 'INHERITS' }
    expect(inherits.length).to eq(1)
  end
end
