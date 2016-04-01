require 'yaml'
require 'war_room/table'
require 'war_room/refinements/array_refinements'

module WarRoom
  using ArrayRefinements

  class Table
    module Generator
      module_function

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

      def generate_linear(die_size, data)
        total_rows = data.length
        return nil if die_size < total_rows

        weight_total = data.map(&:first).reduce(:+)

        die_weighted_table = data.map { |weight, value| [weight / weight_total * die_size, value] }
        integer_table = die_weighted_table.map { |weight, value| [weight.to_i, value] }

        remainder_table = die_weighted_table
                          .map(&:first)
                          .zip(integer_table.map(&:first))
                          .map { |a, b| a - b }
                          .each_with_index.to_a

        # Minimum integer weight should be 1
        integer_table.each_with_index
                     .reject { |(weight, _), _| weight > 0 }
                     .each do |_, index|
          integer_table[index][0] += 1
          remainder_table[index][0] -= 1
        end

        sum = integer_table.map(&:first).reduce(&:+)

        return nil if sum > die_size

        remainder_table.sort! { |row_1, row_2| row_1.first <=> row_2.first }

        (die_size - sum).times do
          remainder, index = remainder_table.pop
          remainder -= 1
          integer_table[index][0] += 1
          remainder_table.insert([remainder, index]) do |other_remainder, _|
            remainder <= other_remainder
          end
        end

        metadata = {
            error: calculate_error(die_size, integer_table, remainder_table)
        }

        pointer = 0
        final_table = integer_table.map do |weight, value|
          range = (pointer + 1)..(pointer + weight)
          pointer = range.end

          {range: range, result: value}
        end

        WarRoom::Table.new die: "d#{die_size}",
                           rows: final_table,
                           metadata: metadata
      end

      def calculate_error(die_size, integer_table, remainder_table)
        relative_errors = remainder_table
                              .map(&:first)
                              .zip(integer_table.map(&:first))
                              .map { |remainder, value| (remainder / value).abs }

        mse = remainder_table.map { |remainder, _| (remainder/die_size)**2 }.reduce(&:+) / remainder_table.length

        {
            mean: relative_errors.reduce(&:+) / relative_errors.length,
            highest: relative_errors.max,
            mse: mse
        }
      end

      def load_yaml(file)
        YAML.load_file(file).map do |pair|
          weight, value = pair.flatten
          [weight.to_f, value.to_s]
        end
      end
    end
  end
end
