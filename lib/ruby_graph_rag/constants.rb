# frozen_string_literal: true

module RubyGraphRag
  module Constants
    NODE_PROJECT = 'Project'
    NODE_FOLDER = 'Folder'
    NODE_FILE = 'File'
    NODE_MODULE = 'Module'
    NODE_CLASS = 'Class'
    NODE_FUNCTION = 'Function'

    REL_CONTAINS_FOLDER = 'CONTAINS_FOLDER'
    REL_CONTAINS_FILE = 'CONTAINS_FILE'
    REL_CONTAINS_MODULE = 'CONTAINS_MODULE'
    REL_DEFINES = 'DEFINES'
    REL_CALLS = 'CALLS'
    REL_INHERITS = 'INHERITS'
    REL_RENDERS = 'RENDERS'

    TYPE_MODULE = :module
    TYPE_CLASS = :class
    TYPE_METHOD = :method

    RUBY_RESERVED = %w[if unless while until case when else elsif do end class module def return yield super begin
                       rescue ensure].freeze
  end
end
