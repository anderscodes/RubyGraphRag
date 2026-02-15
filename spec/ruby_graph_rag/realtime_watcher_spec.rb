# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Realtime::Watcher do
  it 'is constructible' do
    repo = make_repo { |r| r }
    updater = instance_double(RubyGraphRag::GraphUpdater)
    watcher = described_class.new(repo_path: repo, updater: updater)
    expect(watcher).to be_a(described_class)
  end
end
