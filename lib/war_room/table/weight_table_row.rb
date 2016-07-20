# frozen_string_literal: true
require 'dry-types'
require 'war_room/types'

module WarRoom
  module Table
    class WeightTableRow < Dry::Types::Value
      attribute :weight, Types::Coercible::Rational
      attribute :value, Types::Coercible::String

      def +(other)
        case other
        when WeightTableRow
          WeightTableRow.new(weight: (weight + other.weight), value: value)
        else
          WeightTableRow.new(weight: (weight + other), value: value)
        end
      end

      def self.[](row)
        weight, value = *row
        new(weight: weight, value: value)
      end
    end
  end
end
