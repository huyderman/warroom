#!/usr/bin/env ruby
# frozen_string_literal: true
require 'war_room'
require 'war_room/table/generator'
require 'war_room/table/weight_table'
require 'war_room/table/weight_table_row'
require 'trollop'
require 'tty-table'
require 'yaml'

cmd = File.basename(__FILE__)

DICE_STANDARD = %w(d4 d6 d8 d10 d12 d20).freeze
DICE_EXTENDED = %w(d3 d4 d5 d6 d7 d8 d10 d12 d14 d16 d20 d24 d30).freeze
DICE_ALL      = %w(d3 d4 d5 d6 d7 d8 d9 d10 d11 d12 d13 d14 d15 d16 d18 d20 d22 d24 d30).freeze

options = Trollop.options do
  banner <<~TEXT.chomp
    Generate a roll-table

    Usage: #{EXECUTABLE} #{cmd} <data.yml> [options]

    Options:
  TEXT

  dice_desc = <<~TEXT
    Space seperated list of dice to consider when creating table.

    The following are supported:
      * dX       - Regular dice (d6, d20, d100 etc.)
      * d0       - A 10 sided dice, but '10' show as '0'
      * dXX…     - Digit dice, where each die represents a separate digit (d66, d666 or d00)
      * d%, d%%… - Alternate names for d00, d000, etc.
      * standard - alias for [#{DICE_STANDARD.join(' ')}]
      * extended - alias for [#{DICE_EXTENDED.join(' ')}]
      * all      - alias for [#{DICE_ALL.join(' ')}]
  TEXT
  opt :dice, dice_desc, type: :strings, default: %w(standard)
  opt :drop_rows, 'Drop low probability rows', default: false
end

input_file = ARGV.first
Trollop.educate unless input_file

options[:dice].map! do |die|
  case die
  when 'standard'
    DICE_STANDARD
  when 'extended'
    DICE_EXTENDED
  when 'all'
    DICE_ALL
  else
    die
  end
end
options[:dice].flatten!

rows         = YAML.load_file(input_file)
                   .map(&:flatten)
                   .map(&WarRoom::Table::WeightTableRow.method(:[]))
weight_table = WarRoom::Table::WeightTable.new rows: rows
generator    = WarRoom::Table::Generator.new(weight_table, **options)
die_table    = generator.generate(options[:dice])

Trollop.die 'Unable to generate table for the given die/dice' unless die_table

format_range = ->(r) { (r.first != r.last) ? "#{r.first}–#{r.last}" : r.first }

table = TTY::Table.new(header: [die_table.die, 'Result'])
die_table.rows
         .map { |r| [format_range[r.range], r.result] }
         .inject(table, :<<)

puts table.render(:unicode, padding: [0, 1])
