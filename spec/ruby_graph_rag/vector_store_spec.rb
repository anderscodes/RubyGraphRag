# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::VectorStore do
  it 'stores and retrieves ranked embeddings' do
    e1 = RubyGraphRag::Embedder.embed_code("def add(a, b)\n  a + b\nend")
    e2 = RubyGraphRag::Embedder.embed_code("def multiply(a, b)\n  a * b\nend")
    qn1 = 'demo.math.add'
    qn2 = 'demo.math.multiply'
    id1 = described_class.node_id_for(qn1)
    id2 = described_class.node_id_for(qn2)

    described_class.store_embedding(
      node_id: id1,
      embedding: e1,
      payload: { 'qualified_name' => qn1, 'name' => 'add', 'type' => 'Function', 'source' => 'def add(a,b) a+b end' }
    )
    described_class.store_embedding(
      node_id: id2,
      embedding: e2,
      payload: { 'qualified_name' => qn2, 'name' => 'multiply', 'type' => 'Function',
                 'source' => 'def multiply(a,b) a*b end' }
    )

    query = RubyGraphRag::Embedder.embed_code('sum two numbers')
    hits = described_class.search_embeddings(query_embedding: query, top_k: 2)

    expect(hits.length).to eq(2)
    expect(hits.first[0]).to eq(id1)
  end

  it 'returns payload by node id' do
    qn = 'demo.feature.fn'
    id = described_class.node_id_for(qn)
    described_class.store_embedding(
      node_id: id,
      embedding: Array.new(RubyGraphRag::Config.embedding_vector_dim, 0.01),
      payload: { 'qualified_name' => qn, 'source' => 'def fn; end' }
    )

    payload = described_class.payload_for(id)
    expect(payload['qualified_name']).to eq(qn)
  end
end
