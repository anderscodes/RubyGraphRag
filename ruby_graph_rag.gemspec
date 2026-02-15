# frozen_string_literal: true

require_relative 'lib/ruby_graph_rag/version'

Gem::Specification.new do |spec|
  spec.name = 'ruby_graph_rag'
  spec.version = RubyGraphRag::VERSION
  spec.authors = ['Graph Code Team']
  spec.email = ['dev@example.com']

  spec.summary = 'Graph-based RAG indexer for Ruby and Rails codebases'
  spec.description = 'Indexes code into a graph with Ruby, Rails convention, and ERB render relationship extraction.'
  spec.homepage = 'https://example.com/ruby_graph_rag'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir.glob('{lib,exe,sig}/**/*') + %w[README.md LICENSE]
  spec.bindir = 'exe'
  spec.executables = ['ruby-graph-rag']
  spec.require_paths = ['lib']

  spec.add_dependency 'dry-configurable', '~> 1.1'
  spec.add_dependency 'listen', '~> 3.9'
  spec.add_dependency 'neo4j-ruby-driver', '~> 4.4'
  spec.add_dependency 'connection_pool', '~> 2.2'
  spec.add_dependency 'prism', '~> 1.9'
  spec.add_dependency 'pstore'

  spec.add_dependency 'thor', '~> 1.3'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
