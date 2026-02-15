# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Parsers::CallProcessor do
  it 'creates CALLS for method invocations by simple-name resolution' do
    repo = make_repo { |r| "#{r}app/models".mkpath }
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.models.calc.Calc.add' => :method,
      'demo.app.models.calc.Calc.sum' => :method
    }
    lookup = Hash.new { |h, k| h[k] = Set.new }
    lookup['sum'] << 'demo.app.models.calc.Calc.sum'

    parsed = RubyGraphRag::Parsers::ParsedFile.new(
      path: "#{repo}app/models/calc.rb",
      module_qn: 'demo.app.models.calc',
      text: "def add(a,b)\n  sum(a,b)\nend\n",
      methods: [{ qn: 'demo.app.models.calc.Calc.add', name: 'add', owner_qn: 'demo.app.models.calc.Calc', line: 1 }]
    )

    processor = described_class.new(repo_path: repo, project_name: 'demo', ingestor: ingestor,
                                    function_registry: registry, simple_name_lookup: lookup)
    processor.process_calls_in_file(parsed)

    calls = ingestor.relationships.select { |r| r[1] == 'CALLS' }
    expect(calls.length).to be >= 1
    expect(calls.map { |r| r[2][2] }).to include('demo.app.models.calc.Calc.sum')
  end

  it 'prefers same-owner method for bare calls when names are ambiguous' do
    repo = make_repo { |r| "#{r}app/models".mkpath }
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.models.alpha.Alpha.run' => :method,
      'demo.app.models.alpha.Alpha.work' => :method,
      'demo.app.models.beta.Beta.work' => :method
    }
    lookup = Hash.new { |h, k| h[k] = Set.new }
    lookup['work'] << 'demo.app.models.alpha.Alpha.work'
    lookup['work'] << 'demo.app.models.beta.Beta.work'

    parsed = RubyGraphRag::Parsers::ParsedFile.new(
      path: "#{repo}app/models/alpha.rb",
      module_qn: 'demo.app.models.alpha',
      text: "def run\n  work\nend\n",
      methods: [{ qn: 'demo.app.models.alpha.Alpha.run', name: 'run', owner_qn: 'demo.app.models.alpha.Alpha',
                  line: 1 }]
    )

    processor = described_class.new(repo_path: repo, project_name: 'demo', ingestor: ingestor,
                                    function_registry: registry, simple_name_lookup: lookup)
    processor.process_calls_in_file(parsed)

    calls = ingestor.relationships.select { |r| r[1] == 'CALLS' }.map { |r| r[2][2] }
    expect(calls).to include('demo.app.models.alpha.Alpha.work')
    expect(calls).not_to include('demo.app.models.beta.Beta.work')
  end

  it 'resolves receiver calls via local type inference from Class.new' do
    repo = make_repo { |r| "#{r}app/models".mkpath }
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.models.calc.Calc.run' => :method,
      'demo.app.models.math.MathService' => :class,
      'demo.app.models.math.MathService.add' => :method
    }
    lookup = Hash.new { |h, k| h[k] = Set.new }
    lookup['add'] << 'demo.app.models.math.MathService.add'

    parsed = RubyGraphRag::Parsers::ParsedFile.new(
      path: "#{repo}app/models/calc.rb",
      module_qn: 'demo.app.models.calc',
      text: "def run\n  service = MathService.new\n  service.add(1, 2)\nend\n",
      methods: [{ qn: 'demo.app.models.calc.Calc.run', name: 'run', owner_qn: 'demo.app.models.calc.Calc', line: 1 }]
    )

    processor = described_class.new(repo_path: repo, project_name: 'demo', ingestor: ingestor,
                                    function_registry: registry, simple_name_lookup: lookup)
    processor.process_calls_in_file(parsed)

    calls = ingestor.relationships.select { |r| r[1] == 'CALLS' }.map { |r| r[2][2] }
    expect(calls).to include('demo.app.models.math.MathService.add')
  end

  it 'infers association create chains and downstream local variable calls' do
    repo = make_repo { |r| "#{r}app/models".mkpath }
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.models.runner.Runner.run' => :method,
      'demo.app.models.user.User' => :class,
      'demo.app.models.post.Post' => :class,
      'demo.app.models.post.Post.create' => :method,
      'demo.app.models.post.Post.publish!' => :method
    }
    lookup = Hash.new { |h, k| h[k] = Set.new }
    association_registry = {
      'demo.app.models.user.User' => {
        'posts' => ['demo.app.models.post.Post']
      }
    }

    parsed = RubyGraphRag::Parsers::ParsedFile.new(
      path: "#{repo}app/models/runner.rb",
      module_qn: 'demo.app.models.runner',
      text: "def run\n  user = User.new\n  post = user.posts.create(title: 'x')\n  post.publish!\nend\n",
      methods: [{ qn: 'demo.app.models.runner.Runner.run', name: 'run', owner_qn: 'demo.app.models.runner.Runner',
                  line: 1 }]
    )

    processor = described_class.new(
      repo_path: repo,
      project_name: 'demo',
      ingestor: ingestor,
      function_registry: registry,
      simple_name_lookup: lookup,
      association_registry: association_registry
    )
    processor.process_calls_in_file(parsed)

    calls = ingestor.relationships.select { |r| r[1] == 'CALLS' }.map { |r| r[2][2] }
    expect(calls).to include('demo.app.models.post.Post.create')
    expect(calls).to include('demo.app.models.post.Post.publish!')
  end

  it 'infers build_association return types for singular associations' do
    repo = make_repo { |r| "#{r}app/models".mkpath }
    ingestor = RubyGraphRag::Services::InMemoryIngestor.new
    registry = {
      'demo.app.models.runner.Runner.run' => :method,
      'demo.app.models.user.User' => :class,
      'demo.app.models.profile.Profile' => :class,
      'demo.app.models.profile.Profile.touch' => :method
    }
    lookup = Hash.new { |h, k| h[k] = Set.new }
    association_registry = {
      'demo.app.models.user.User' => {
        'profile' => ['demo.app.models.profile.Profile']
      }
    }

    parsed = RubyGraphRag::Parsers::ParsedFile.new(
      path: "#{repo}app/models/runner.rb",
      module_qn: 'demo.app.models.runner',
      text: "def run\n  user = User.new\n  profile = user.build_profile\n  profile.touch\nend\n",
      methods: [{ qn: 'demo.app.models.runner.Runner.run', name: 'run', owner_qn: 'demo.app.models.runner.Runner',
                  line: 1 }]
    )

    processor = described_class.new(
      repo_path: repo,
      project_name: 'demo',
      ingestor: ingestor,
      function_registry: registry,
      simple_name_lookup: lookup,
      association_registry: association_registry
    )
    processor.process_calls_in_file(parsed)

    calls = ingestor.relationships.select { |r| r[1] == 'CALLS' }.map { |r| r[2][2] }
    expect(calls).to include('demo.app.models.profile.Profile.touch')
  end
end
