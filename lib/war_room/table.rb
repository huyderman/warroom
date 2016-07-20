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

options = Trollop.options do
  banner <<~TEXT.chomp
    Generate a roll-table

    Usage: #{EXECUTABLE} #{cmd} <data.yml> [options]

    Options:
  TEXT

  opt :dice, 'Die type to generate table for',
      type: :strings, default: %w(d4 d6 d8 d10 d12 d20)
  opt :drop_rows, 'Drop low probability rows', default: false
end

input_file = ARGV.first
Trollop.educate unless input_file

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
