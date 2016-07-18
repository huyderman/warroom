# frozen_string_literal: true
require 'dry-types'

Dry::Types.register('range', Dry::Types::Definition[Range].new(Range))
Dry::Types.register('strict.range', Dry::Types['range'].constrained(type: Range))

Dry::Types.register('rational', Dry::Types::Definition[Rational].new(Rational))
Dry::Types.register('strict.rational', Dry::Types['rational'].constrained(type: Rational))
Dry::Types.register('coercible.rational', Dry::Types['rational'].constructor(Kernel.method(:Rational)))

module WarRoom
  module Types
    include Dry::Types.module
  end
end
