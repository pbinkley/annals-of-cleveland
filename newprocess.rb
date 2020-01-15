#!/usr/bin/env ruby

# frozen_string_literal: true

require 'json'
require './lib/sourcetext.rb'

require 'byebug'

year = 1845 # TODO: read from metadata for volume

source = SourceText.new(ARGV[0])

issues = IssuesTextMap.new('issues')

abstracts = source.parse_abstracts(year, issues)
byebug
headings = source.parse_headings

File.open('./intermediate/headings.txt', 'w') do |f|
  headings.keys.each do |key|
    this = headings[key]

    f.puts "#{this[:source_page]}|#{this[:start]}|#{this[:type]}|#{this[:text]}"
    next unless this[:subheading1]

    this[:subheading1].each do |subh1|
      f.puts "  #{subh1[:source_page]}|#{subh1[:start]}|#{subh1[:type]}|#{subh1[:text]}"
      next unless subh1[:subheading2]

      subh1[:subheading2].each do |subh2|
        f.puts "    #{subh2[:source_page]}|#{subh2[:start]}|#{subh2[:type]}|#{subh2[:text]}"
      end
    end
  end
end

puts 'Pages: ' + source.page_number_list.count.to_s
puts 'Headings: ' + headings.count.to_s
byebug
puts 'Abstracts: ' + abstracts.hash.keys.count.to_s
puts 'Issues: ' + issues.hash.keys.count.to_s

File.open('output/data.json', 'w') do |f|
  f.puts JSON.pretty_generate(
    'abstracts': abstracts.data,
    'headings': headings,
    'issues': issues.hash
  )
end

puts 'Data written to output/data.json'