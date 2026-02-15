# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Services::Neo4jBoltIngestor do
  class FakeResult
    def initialize(rows)
      @rows = rows
    end

    def to_a
      @rows
    end
  end

  class FakeRecord
    def initialize(hash)
      @hash = hash
    end

    def to_h
      @hash
    end
  end

  class FakeTx
    attr_reader :calls

    def initialize
      @calls = []
    end

    def run(query, params = {})
      @calls << [query, params]
      FakeResult.new([FakeRecord.new({ 'ok' => true })])
    end
  end

  class FakeSession
    attr_reader :tx

    def initialize
      @tx = FakeTx.new
    end

    def write_transaction
      yield @tx
    end

    def read_transaction
      yield @tx
    end

    def close; end
  end

  class FakeDriver
    attr_reader :sessions

    def initialize
      @sessions = []
    end

    def session
      s = FakeSession.new
      @sessions << s
      s
    end

    def close; end
  end

  it 'writes nodes and relationships through bolt driver' do
    driver = FakeDriver.new
    ingestor = described_class.new(driver: driver)

    ingestor.ensure_node_batch('Function', { 'qualified_name' => 'a.b.c', 'name' => 'c' })
    ingestor.ensure_relationship_batch(
      ['Function', 'qualified_name', 'a.b.c'],
      'CALLS',
      ['Function', 'qualified_name', 'a.b.d']
    )

    all_calls = driver.sessions.flat_map { |s| s.tx.calls }
    expect(all_calls.any? { |q, _| q.include?('MERGE (n:Function') }).to eq(true)
    expect(all_calls.any? { |q, _| q.include?('MERGE (a)-[r:CALLS]->(b)') }).to eq(true)
  end

  it 'supports fetch_all' do
    driver = FakeDriver.new
    ingestor = described_class.new(driver: driver)

    rows = ingestor.fetch_all('MATCH (n) RETURN n')
    expect(rows).to eq([{ 'ok' => true }])
  end
end
