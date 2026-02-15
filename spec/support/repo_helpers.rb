# frozen_string_literal: true

require 'pathname'

class RepoPath
  def initialize(path)
    @path = Pathname.new(path)
  end

  def to_s
    "#{@path}/"
  end

  def to_path
    @path.to_s
  end

  def basename
    @path.basename
  end
end

class String
  def mkpath
    Pathname.new(self).mkpath
  end

  def write(content)
    Pathname.new(self).write(content)
  end
end
