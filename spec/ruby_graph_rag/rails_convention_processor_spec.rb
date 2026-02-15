# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Parsers::RailsConventionProcessor do
  it 'creates RENDERS for implicit controller action views' do
    repo = make_repo do |r|
      "#{r}app/controllers".mkpath
      "#{r}app/views/users".mkpath
      "#{r}app/views/users/show.html.erb".write('<h1>show</h1>')
    end

    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.controllers.users_controller.UsersController.show' => :method
    }

    processor = described_class.new(repo_path: repo, project_name: 'demo', ingestor: ingestor,
                                    function_registry: registry)
    processor.process

    renders = ingestor.relationships.select { |r| r[1] == 'RENDERS' }
    expect(renders.map { |r| r[2][2] }).to include('app/views/users/show.html.erb')
  end
end
