# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Rails render resolution' do
  def build_repo
    make_repo do |r|
      "#{r}app/controllers".mkpath
      "#{r}app/views/users".mkpath
      "#{r}app/views/shared".mkpath
      "#{r}app/views/admin".mkpath
      "#{r}app/controllers/users_controller.rb".write <<~RUBY
        class UsersController < ApplicationController
          def show
            render :edit
            render template: "admin/show"
            render action: "show"
            render partial: "shared/nav"
            render locals: { title: "X" }, partial: "shared/nav"
          end
        end
      RUBY
      "#{r}app/views/users/edit.html.erb".write('edit')
      "#{r}app/views/users/show.html.erb".write('show')
      "#{r}app/views/shared/_nav.html.erb".write('nav')
      "#{r}app/views/admin/show.html.erb".write('admin')
      "#{r}app/views/users/index.html.erb".write('<%= render "shared/nav" %>')
    end
  end

  it 'resolves common render forms from controllers' do
    repo = build_repo
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    RubyGraphRag::GraphUpdater.new(repo_path: repo, ingestor: ingestor).run

    renders = ingestor.relationships.select { |r| r[1] == 'RENDERS' }.map { |r| r[2][2] }

    expect(renders).to include('app/views/users/edit.html.erb')
    expect(renders).to include('app/views/users/show.html.erb')
    expect(renders).to include('app/views/admin/show.html.erb')
    expect(renders).to include('app/views/shared/_nav.html.erb')
  end

  it 'resolves ERB shorthand render string paths as partials' do
    repo = build_repo
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    RubyGraphRag::GraphUpdater.new(repo_path: repo, ingestor: ingestor).run

    renders = ingestor.relationships.select { |r| r[1] == 'RENDERS' }
    from_index = renders.select { |r| r[0] == ['File', 'path', 'app/views/users/index.html.erb'] }
    expect(from_index.map { |r| r[2][2] }).to include('app/views/shared/_nav.html.erb')
  end
end
