# frozen_string_literal: true
require 'dry-types'

module WarRoom
  module Types
    include Dry::Types.module
  end
end

Dry::Types.register('range', Dry::Types::Definition[Range].new(Range))
