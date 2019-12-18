#!/usr/bin/env ruby

# frozen_string_literal: true

require './lib/sourcetext.rb'

require 'byebug'

year = 1845 # TODO: read from metadata for volume

source = SourceText.new(ARGV[0])

entries = source.parse_entries(year)

headings = source.parse_headings

puts 'Pages: ' + source.page_number_list.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Entries: ' + entries.count.to_s
