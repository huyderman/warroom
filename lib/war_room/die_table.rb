require 'dry-types'
require 'terminal-table'
require 'war_room/types'

module WarRoom
  class DieTable < Dry::Types::Struct
    class DieTableRow < Dry::Types::Struct
      attribute :range, Range
      attribute :result, Types::Coercible::String
    end

    attribute :die,      Types::Coercible::String
    attribute :rows,     Types::Coercible::Array.member(DieTableRow)
    attribute :metadata, Types::Hash

    def to_s
      table_rows = rows.map do |table_row|
        [die_range_string(table_row.range), table_row.result]
      end

      Terminal::Table.new(headings: [die, 'Result'], rows: table_rows).to_s
    end

    private

    def die_range_string(range)
      if range.begin == range.end
        range.begin
      else
        "#{range.begin}–#{range.end}"
      end
    end
  end
end
