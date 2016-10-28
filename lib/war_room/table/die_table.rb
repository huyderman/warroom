# frozen_string_literal: true
require 'dry-struct'
require 'war_room/types'
require 'war_room/table/die_table_row'

module WarRoom
  module Table
    class DieTable < Dry::Struct
      attribute :die, Types::Coercible::String
      attribute :rows, Types::Coercible::Array.member(DieTableRow)
      attribute :metadata, Types::Hash
    end
  end
end
