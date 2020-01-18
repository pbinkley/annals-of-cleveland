#!/usr/bin/env ruby

# frozen_string_literal: true

require 'json'
require './lib/sourcetext.rb'

require 'byebug'

year = 1845 # TODO: read from metadata for volume

source = SourceText.new(ARGV[0])

abstracts = source.parse_abstracts(year)

headings = source.parse_headings

terms = source.parse_terms

File.open('./intermediate/abstract.txt', 'w') do |f|
  abstracts.hash.keys.each do |key|
    this = abstracts.hash[key]
    f.puts "#{key}|#{this.id}|#{this.source_page}|#{this.heading}|#{this.terms}"
  end
end
    
File.open('./intermediate/headings.txt', 'w') do |f|
  headings.hash.keys.each do |key|
    this = headings.hash[key]

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

puts 'Pages: ' + source.page_number_count.to_s
puts 'Headings: ' + headings.hash.keys.count.to_s
puts 'Abstracts: ' + abstracts.hash.keys.count.to_s
puts 'Issues: ' + abstracts.issuesCount.to_s

File.open('output/data.json', 'w') do |f|
  f.puts JSON.pretty_generate(
    'abstracts': abstracts.abstractsData,
    'headings': headings.hash,
    'terms': terms.termsData,
    'issues': abstracts.issuesData
  )
end

puts 'Data written to output/data.json'