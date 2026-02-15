# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyGraphRag::Parsers::RailsAssociationProcessor do
  it 'extracts common model associations into a registry' do
    repo = make_repo do |r|
      "#{r}app/models".mkpath
      "#{r}app/models/user.rb".write <<~RUBY
        class User < ApplicationRecord
          has_many :posts
          has_one :profile, class_name: "Accounts::Profile"
          belongs_to :account
        end
      RUBY
    end

    registry = {
      'demo.app.models.user.User' => :class,
      'demo.app.models.post.Post' => :class,
      'demo.app.models.account.Account' => :class,
      'demo.app.models.accounts.profile.Accounts.Profile' => :class
    }
    association_registry = Hash.new { |h, k| h[k] = {} }

    processor = described_class.new(
      repo_path: repo,
      project_name: 'demo',
      function_registry: registry,
      association_registry: association_registry
    )
    processor.process

    user_associations = association_registry['demo.app.models.user.User']
    expect(user_associations['posts']).to include('demo.app.models.post.Post')
    expect(user_associations['profile']).to include('demo.app.models.accounts.profile.Accounts.Profile')
    expect(user_associations['account']).to include('demo.app.models.account.Account')
  end
end
