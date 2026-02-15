# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'fileutils'
require 'pathname'
require 'tmpdir'
require_relative '../lib/ruby_graph_rag'
require_relative 'support/repo_helpers'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:each) do |example|
    Dir.mktmpdir('ruby_graph_rag_spec') do |dir|
      @tmp_dir = Pathname.new(dir)
      RubyGraphRag::Config.reset!
      RubyGraphRag::Config.config.semantic_store_path = "#{@tmp_dir}semantic_store.pstore"
      RubyGraphRag::Config.config.embedding_backend = 'local_hash'
      RubyGraphRag::Config.config.qdrant_url = ''
      RubyGraphRag::Config.config.semantic_backend = 'in_memory'
      RubyGraphRag::VectorStore.reset_store!
      example.run
      RubyGraphRag::VectorStore.reset_store!
      RubyGraphRag::Config.reset!
    end
  end

  config.define_derived_metadata do |meta|
    meta[:tmp_dir] = @tmp_dir if defined?(@tmp_dir)
  end
end

def make_repo
  dir = Pathname.new(Dir.mktmpdir('ruby_graph_rag_repo'))
  repo = RepoPath.new(dir)
  yield repo
  repo
end
