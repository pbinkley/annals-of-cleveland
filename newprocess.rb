#!/usr/bin/env ruby

require './lib/sourcetext.rb'

require 'byebug'

year = 1845 # TODO: read from metadata for volume

source = SourceText.new(ARGV[0])

entries = source.parseEntries(year)

headings = source.parseHeadings

puts 'Pages: ' + source.pageNumberList.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Entries: ' + entries.count.to_s
