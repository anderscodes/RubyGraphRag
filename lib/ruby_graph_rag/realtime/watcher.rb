# frozen_string_literal: true

require 'listen'

module RubyGraphRag
  module Realtime
    class Watcher
      def initialize(repo_path:, updater:)
        @repo_path = repo_path
        @updater = updater
      end

      def start
        listener = Listen.to(@repo_path.to_s) do |_modified, _added, _removed|
          @updater.run
        end
        listener.start
        sleep
      end
    end
  end
end
