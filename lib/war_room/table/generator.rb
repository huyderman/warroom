# frozen_string_literal: true
require 'dry-types'
require 'war_room/types'
require 'war_room/table/die_table'
require 'war_room/table/weight_table'
require 'dry-initializer'

module WarRoom
  module Table
    # Generator for Die Tables
    class Generator
      extend Dry::Initializer::Mixin

      tolerant_to_unknown_options
      param :weight_table, type: WeightTable
      option :drop_rows, type: Types::Strict::Bool, default: proc { false }

      def generate(dice)
        tables = dice.map do |die|
          case die
          when 'd0'
            generate_nn(0, 1, die)
          when /^d(%+)$/
            digits = Regexp.last_match(1).length
            generate_nn(0, digits+1, die)
          when /^d([0-9]+)$/
            die_size = Regexp.last_match(1)
            digits   = die_size.length
            if digits > 1 && die_size.chars.reduce { |a, e| a == e && a }
              generate_nn(die_size[0].to_i, digits, die)
            else
              generate_linear(die_size.to_i, die)
            end
          else
            raise "Die type not supported: #{die}"
          end
        end

        tables.compact.sort_by { |table| table.metadata[:error][:mse] }.first
      end

      private

      def generate_nn(digit, digits, die)
        percentile_digit = digit == 0
        digit            = 10 if percentile_digit
        table            = generate_linear((digit**digits).to_i, die)
        table            = DieTable.new(**table, die: die)

        if percentile_digit
          numbers = ([(0...digit).to_a] * digits).reduce(&:product).map(&Kernel.method(:Array)).map(&:join)
          numbers.push(numbers.shift)
        else
          numbers = ([(1..digit).to_a] * digits).reduce(&:product).map(&Kernel.method(:Array)).map(&:join)
        end

        rows = table.rows.map do |row|
          range = Range.new(
            numbers[(row.range.min - 1)],
            numbers[(row.range.max - 1)]
          )
          DieTableRow.new(**row, range: range)
        end

        DieTable.new(**table, rows: rows)
      end

      def generate_linear(die_size, die)
        total_rows = weight_table.length

        # Do we have more rows than sides on the die?
        if die_size < total_rows
          # If we can't drop rows, we can't generate
          # a valid table for this die size
          return nil unless drop_rows
        end

        # Normalize weights to the given die size
        normalized_table = weight_table.normalize(die_size)

        # Create quick'n'dirty table with integer weights.
        integer_table = normalized_table.map_weights(&:to_i)

        # If all rows are to be included, all weights are set to minimum 1
        unless drop_rows
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

          rows << DieTableRow.new(range:  range, result: row.value)
        end

        DieTable.new die:      die,
                     rows:     rows,
                     metadata: metadata
      end

      def calculate_error(die_size, integer_table, remainders)
        absolute_errors = remainders
                          .map { |remainder| (remainder / die_size).abs }

        relative_errors = remainders.zip(integer_table.map(&:weight))
                                    .map do |remainder, weight|
          (remainder / (remainder + weight)).abs
        end

        mse = absolute_errors.map { |error| error**2 }.reduce(:+)
        mse /= absolute_errors.length

        {
          mean: relative_errors.reduce(:+) / relative_errors.length,
          highest: relative_errors.max,
          mse: mse
        }
      end
    end
  end
end
