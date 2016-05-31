require 'yaml'
require 'dry-types'
require 'war_room/types'
require 'war_room/die_table'

module WarRoom
  class DieTable
    module Generator
      module_function

      class WeightRow < Dry::Types::Struct
        attribute :weight, Types::Coercible::Float
        attribute :value, Types::Coercible::String

        def +(other)
          case other
          when WeightRow
            WeightRow.new(weight: (weight + other.weight), value: value)
          else
            WeightRow.new(weight: (weight + other), value: value)
          end
        end
      end

      class WeightTable < Dry::Types::Struct
        include Enumerable

        attribute :rows, Types::Array.member(WeightRow)

        def each
          return rows.each unless block_given?

          rows.each { |row| yield(row) }
        end

        def reject
          return rows.reject unless block_given?

          WeightTable.new(rows: rows.reject { |row| yield(row) })
        end

        def map_table
          WeightTable.new(rows: rows.map { |row| yield(row) })
        end

        def map_weights
          map_table do |row|
            WeightRow.new(weight: yield(row.weight),
                          value: row.value)
          end
        end

        def length
          rows.length
        end

        def normalize(size = 1.0)
          total_weight = weight_sum

          map_weights do |weight|
            weight / total_weight * size
          end
        end

        def weight_sum
          rows.map(&:weight).reduce(:+)
        end
      end

      def generate(dice, data, **opts)
        tables = dice.map do |die|
          case die
          when /^d([0-9]+)$/
            Generator.generate_linear(Regexp.last_match(1).to_i, data, opts)
          else
            raise "Die type not supported: #{die}"
          end
        end

        tables.compact.sort_by { |table| table.metadata[:error][:mse] }.first
      end

      def generate_linear(die_size, table, include_all: true, **_)
        total_rows = table.length

        # Do we have more rows than sides on the die?
        if die_size < total_rows
          # If we can't drop rows, we can't generate
          # a valid table for this die size
          return nil if include_all

          # If we're allowed to drop rows, we preemptively drop
          # any row with a weight lower than the nth highest weight.
          cut_off = table.map(&:weight).sort.last(die_size).first
          table = table.reject { |row| row.weight < cut_off }
        end

        # Normalize weights to the given die size
        normalized_table = table.normalize(die_size)

        # Create quick'n'dirty table with integer weights.
        integer_table = normalized_table.map_weights(&:to_i)

        # If all rows are to be included, all weights are set to minimum 1
        if include_all
          integer_table = integer_table.map_weights do |weight|
            weight > 0 ? weight : 1
          end
        end

        sum = integer_table.weight_sum.to_i
        # Sanity check. If the total of integer weights is
        # greater than the die size, this table is invalid.
        return nil if sum > die_size

        # Calculate the difference between
        # the integer weights and actual weights
        remainders = normalized_table
                     .map(&:weight)
                     .zip(integer_table.map(&:weight))
                     .map { |weight, int_weight| weight - int_weight }

        # All remainders should be less than 1,
        # if not then something is wrong
        remainders.each do |remainder|
          unless remainder < 1
            raise "Remainder is not less than 1: #{remainder}"
          end
        end

        # If we have "left-overs", we add these to the n rows
        # with the highest error, and adjust the remainders table
        if die_size > sum
          remainders.each_with_index
                    .sort_by { |remainder, _| remainder }
                    .last(die_size - sum).each do |_, index|
            remainders[index] -= 1
            integer_table.rows[index] += 1
          end
        end

        # If the integer weights don't add up to the die size
        # then something is wrong
        unless integer_table.weight_sum == die_size
          raise "Integer weight sum is not #{die_size}"
        end

        metadata = {
          error: calculate_error(die_size, integer_table.rows, remainders)
        }

        pointer = 0
        rows = []
        integer_table.reject { |row| row.weight == 0 }.each do |row|
          range = Range.new((pointer + 1).to_i, (pointer + row.weight).to_i)
          pointer = range.end

          rows << WarRoom::DieTable::DieTableRow.new(range: range,
                                                     result: row.value)
        end

        WarRoom::DieTable.new die:      "d#{die_size}",
                              rows:     rows,
                              metadata: metadata
      end

      def calculate_error(die_size, integer_table, remainders)
        relative_errors = remainders
                          .zip(integer_table.map(&:weight))
                          .map { |remainder, value| (remainder / value).abs }

        mse = remainders.map { |remainder| (remainder / die_size)**2 }
                        .reduce(:+) / remainders.length

        {
          mean: relative_errors.reduce(:+) / relative_errors.length,
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
