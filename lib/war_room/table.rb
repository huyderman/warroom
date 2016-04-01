require 'virtus'
require 'terminal-table'

module WarRoom
  class Table
    include Virtus.model

    class TableRow
      include Virtus.value_object

      values do
        attribute :range, Range
        attribute :result
      end
    end

    attribute :die,      String
    attribute :rows,     Array[TableRow]
    attribute :metadata, Hash[Symbol => Object]

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
