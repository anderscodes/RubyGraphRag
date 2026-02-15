# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Parsers::ErbProcessor do
  it 'extracts render partial calls from ERB blocks' do
    repo = make_repo do |r|
      "#{r}app/views/users".mkpath
      "#{r}app/views/shared".mkpath
      "#{r}app/views/users/show.html.erb".write("<%= render partial: 'shared/nav' %>")
      "#{r}app/views/shared/_nav.html.erb".write('<nav></nav>')
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    call_processor = RubyGraphRag::Parsers::CallProcessor.new(
      repo_path: repo,
      project_name: repo.basename.to_s,
      ingestor: ingestor,
      function_registry: {},
      simple_name_lookup: Hash.new { |h, k| h[k] = Set.new }
    )

    processor = described_class.new(repo_path: repo, project_name: repo.basename.to_s, ingestor: ingestor,
                                    call_processor: call_processor)
    processor.process_erb_file("#{repo}app/views/users/show.html.erb")

    renders = ingestor.relationships.select { |r| r[1] == 'RENDERS' }
    expect(renders.map { |r| r[2][2] }).to include('app/views/shared/_nav.html.erb')
    expect(renders.map { |r| r[0] }).to include(['File', 'path', 'app/views/users/show.html.erb'])
  end
end
