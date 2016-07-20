# frozen_string_literal: true
require 'dry-types'
require 'war_room/types'

module WarRoom
  module Table
    class DieTableRow < Dry::Types::Value
      attribute :range, Types::Range
      attribute :result, Types::Coercible::String

      def to_a
        [range, result]
      end
    end
  end
end
