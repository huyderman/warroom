require 'yaml'
require 'dry-types'
require 'war_room/types'
require 'war_room/table'

module WarRoom
  class Table
    module Generator
      module_function

      class WeightRow < Dry::Types::Struct
        attribute :weight, Types::Coercible::Float
        attribute :value, Types::Coercible::String

        def +(n)
          WeightRow.new weight: weight+n, value: value
        end
      end

      class WeightTable < Dry::Types::Struct
        include Enumerable

        attribute :rows, Types::Array.member(WeightRow)

        def each(&block)
          rows.each(&block)
        end

        def length
          rows.length
        end

        def normalize(n = 1.0)
          total_weight = weight_sum
          normalized_rows = rows.map do |row|
            WeightRow.new weight: row.weight / total_weight * n,
                          value:  row.value
          end
          WeightTable.new rows: normalized_rows
        end

        def weight_sum
          rows.map(&:weight).reduce(:+)
        end
      end

      def generate(*dice, data)
        tables = dice.map do |die|
          case die
            when /^d([0-9]+)$/
              Generator.generate_linear(Regexp.last_match(1).to_i, data)
            else
              raise "Die type not supported: #{die}"
          end
        end

        tables.compact.sort_by { |table| table.metadata[:error][:mse] }.first
      end

      def generate_linear(die_size, table)
        total_rows = table.length
        return nil if die_size < total_rows

        die_weighted_table = table.normalize(die_size)
        integer_rows       = die_weighted_table.map do |row|
          WeightRow.new weight: row.weight > 1 ? row.weight.to_i : 1,
                        value: row.value
        end
        integer_table = WeightTable.new rows: integer_rows

        sum = integer_table.weight_sum.to_i
        return nil if sum > die_size

        remainders = die_weighted_table.map(&:weight)
                     .zip(integer_table.map(&:weight))
                     .map { |a, b| a - b }

        remainders.each_with_index
                  .sort_by { |remainder, _| remainder }
                  .first(die_size - sum).each do |_, index|
          remainders[index] -= 1
          integer_table.rows[index] += 1
        end

        metadata = {
            error: calculate_error(die_size, integer_table.rows, remainders)
        }

        pointer = 0
        final_table = integer_table.map do |row|
          range = (pointer + 1).to_i..(pointer + row.weight).to_i
          pointer = range.end

          { range: range, result: row.value }
        end

        WarRoom::Table.new die: "d#{die_size}",
                           rows: final_table,
                           metadata: metadata
      end

      def calculate_error(die_size, integer_table, remainders)
        relative_errors = remainders
                          .zip(integer_table.map(&:weight))
                          .map { |remainder, value| (remainder / value).abs }

        mse = remainders.map { |remainder| (remainder/die_size)**2 }
                        .reduce(&:+) / remainders.length

        {
            mean: relative_errors.reduce(&:+) / relative_errors.length,
            highest: relative_errors.max,
            mse: mse
        }
      end

      def load_yaml(file)
        rows = YAML.load_file(file).map do |pair|
          weight, value = pair.flatten
          WeightRow.new weight: weight, value: value
        end
        WeightTable.new rows: rows
      end
    end
  end
end
