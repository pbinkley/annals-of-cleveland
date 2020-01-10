#!/usr/bin/env ruby

# frozen_string_literal: true

require './lib/sourcetext.rb'
require './lib/issuelist.rb'

require 'byebug'

year = 1845 # TODO: read from metadata for volume

source = SourceText.new(ARGV[0])

issues = IssueList.new

abstracts = source.parse_abstracts(year, issues)

headings = source.parse_headings

File.open('./intermediate/headings.txt', 'w') do |f|
  headings[:headings].keys.each do |key|
    this = headings[:headings][key]

    f.puts "#{this[:page_num]}|#{this[:start]}|#{this[:type]}|#{this[:text]}"
    next unless this[:subheading1]

    this[:subheading1].each do |subh1|
      f.puts "  #{subh1[:page_num]}|#{subh1[:start]}|#{subh1[:type]}|#{subh1[:text]}"
      next unless subh1[:subheading2]

      subh1[:subheading2].each do |subh2|
        f.puts "    #{subh2[:page_num]}|#{subh2[:start]}|#{subh2[:type]}|#{subh2[:text]}"
      end
    end
  end
end

puts 'Pages: ' + source.page_number_list.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Abstracts: ' + abstracts.count.to_s
puts 'Issues: ' + issues.list.keys.count.to_s
