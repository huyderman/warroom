# frozen_string_literal: true
require 'dry-struct'
require 'war_room/types'
require 'war_room/table/weight_table_row'

module WarRoom
  module Table
    class WeightTable < Dry::Struct
      include Enumerable

      attribute :rows, Types::Array.member(WeightTableRow)

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
          WeightTableRow.new(weight: yield(row.weight),
                             value:  row.value)
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
  end
end
