# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Embedder do
  it 'returns a normalized embedding with configured dimensionality' do
    RubyGraphRag::Config.config.embedding_backend = 'local_hash'
    embedding = described_class.embed_code("def add(a, b)\n  a + b\nend")
    expect(embedding.length).to eq(RubyGraphRag::Config.embedding_vector_dim)
    norm = Math.sqrt(embedding.sum { |v| v * v })
    expect(norm).to be_within(0.0001).of(1.0)
  end

  it 'produces more similar embeddings for semantically close code snippets' do
    RubyGraphRag::Config.config.embedding_backend = 'local_hash'
    emb1 = described_class.embed_code("def add(a, b)\n  a + b\nend")
    emb2 = described_class.embed_code("def add_numbers(left, right)\n  left + right\nend")
    emb3 = described_class.embed_code("class DatabaseConnection\n  def connect\n    open_socket\n  end\nend")

    similarity_12 = cosine(emb1, emb2)
    similarity_13 = cosine(emb1, emb3)
    expect(similarity_12).to be > similarity_13
  end

  it 'uses OpenAI-compatible embeddings when configured' do
    RubyGraphRag::Config.config.embedding_backend = 'openai'
    RubyGraphRag::Config.config.openai_api_key = 'test-key'
    RubyGraphRag::Config.config.openai_base_url = 'https://api.openai.test/v1'
    RubyGraphRag::Config.config.embedding_model = 'text-embedding-3-small'

    response = instance_double(Net::HTTPResponse, code: '200', body: '{"data":[{"embedding":[0.1,0.2,0.3]}]}')
    fake_http = instance_double(Net::HTTP)
    allow(fake_http).to receive(:request).and_return(response)

    expect(Net::HTTP).to receive(:start).with(
      'api.openai.test',
      443,
      hash_including(use_ssl: true)
    ).and_yield(fake_http)

    embedding = described_class.embed_code("def hello\n  1\nend")
    expect(embedding).to eq([0.1, 0.2, 0.3])
  end

  it 'raises when openai backend is configured without api key' do
    RubyGraphRag::Config.config.embedding_backend = 'openai'
    RubyGraphRag::Config.config.openai_api_key = ''

    expect do
      described_class.embed_code("def hello\n  1\nend")
    end.to raise_error(RubyGraphRag::EmbeddingError, /OPENAI_API_KEY/)
  end

  def cosine(vec_a, vec_b)
    dot = vec_a.zip(vec_b).sum { |x, y| x * y }
    norm_a = Math.sqrt(vec_a.sum { |v| v * v })
    norm_b = Math.sqrt(vec_b.sum { |v| v * v })
    dot / (norm_a * norm_b)
  end
end
