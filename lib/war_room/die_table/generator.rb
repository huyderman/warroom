require 'yaml'
require 'dry-types'
require 'war_room/types'
require 'war_room/die_table'

module WarRoom
  class DieTable
    module Generator
      module_function

      class WeightRow < Dry::Types::Struct
        attribute :weight, Types::Coercible::Rational
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
            die_size = Regexp.last_match(1)
            digits   = die_size.length
            if digits > 1 && die_size.chars.reduce { |a, b| a == b && a }
              Generator.generate_nn(die_size[0].to_i, digits, data, opts)
            else
              Generator.generate_linear(die_size.to_i, data, opts)
            end
          else
            raise "Die type not supported: #{die}"
          end
        end

        tables.compact.sort_by { |table| table.metadata[:error][:mse] }.first
      end

      def generate_nn(digit, digits, data, **opts)
        digit     = 10 if digit == 0
        table     = Generator.generate_linear((digit**digits).to_i, data, opts)
        die       = digit == 10 ? "d#{'0' * digits}" : "d#{digit.to_s * digits}"
        table     = DieTable.new(**table, die: die)

        digit_set = digit == 10 ? (0...digit) : (1..digit)
        numbers   = ([digit_set.to_a] * digits).reduce(&:product).map(&:join)
        numbers.push(numbers.shift) if digit == 10

        table.rows.map! do |row|
          range = Range.new(numbers[row.range.begin - 1], numbers[row.range.end - 1])
          DieTableRow.new(range: range, result: row.result)
        end

        table
      end

      def generate_linear(die_size, table, include_all: true, **_)
        total_rows = table.length

        # Do we have more rows than sides on the die?
        if die_size < total_rows
          # If we can't drop rows, we can't generate
          # a valid table for this die size
          return nil if include_all
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
        absolute_errors = remainders
                          .map { |remainder| (remainder / die_size).abs }

        relative_errors = remainders
                          .zip(integer_table.map(&:weight))
                          .map { |remainder, weight| (remainder / (remainder + weight)).abs }

        mse = absolute_errors.map { |error| (error)**2 }.reduce(:+) / absolute_errors.length

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
