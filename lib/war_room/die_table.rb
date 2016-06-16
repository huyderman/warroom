require 'dry-types'
require 'war_room/types'

module WarRoom
  class DieTable < Dry::Types::Struct
    class DieTableRow < Dry::Types::Struct
      attribute :range, Range
      attribute :result, Types::Coercible::String

      def to_a
        [range, result]
      end
    end

    attribute :die,      Types::Coercible::String
    attribute :rows,     Types::Coercible::Array.member(DieTableRow)
    attribute :metadata, Types::Hash
  end
end
