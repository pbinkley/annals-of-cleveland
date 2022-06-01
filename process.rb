#!/usr/bin/env ruby

# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pathname'
require './lib/hugo.rb'
require './lib/sourcetext.rb'

require 'byebug'

filename = ARGV[0] || 'source/1864/1864-corrected.html'

pn = Pathname.new(filename)
year = pn.dirname.basename.to_s.to_i
FileUtils.mkdir_p("./intermediate/#{year}")

puts "Source: #{filename}; year: #{year}"

source = SourceText.new(filename, year)

abstracts = source.parse_abstracts

headings = source.parse_headings(abstracts)

abstracts.hash.keys.sort.each do |key|
  abstract = abstracts.hash[key]
end

keys = headings.headings_data.keys
headings_hash = []
counts = Hash.new(0)
keys.each do |key|
  headings_hash << headings.headings_data[key] if ['see', 'see abstract', 'see heading'].include?(headings.headings_data[key][:type])
  counts[headings.headings_data[key][:type]] += 1
  counts[headings.headings_data[key].class] += 1
  counts[headings.headings_data[key].count] += 1
end

headings.headings_data.keys
  .map { |k| headings.headings_data[k] }
  .sort_by { |h| h[:start] }
  .each do |h| 
    puts "start: #{h[:start]}: #{h[:type]}"
end

terms = source.parse_terms

File.open("./intermediate/#{year}/abstract.txt", 'w') do |f|
  abstracts.hash.keys.sort.each do |key|
    this = abstracts.hash[key]
    f.puts "#{key}|#{this.id}|#{this.source_page}|#{this.heading}|#{this.terms}"
  end
end

File.open("./intermediate/#{year}/headings.txt", 'w') do |f|
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

@data = {
  abstracts: abstracts,
  headings: headings.headings_data,
  terms: terms.terms_data,
  issues: abstracts.issues_data
}

# rehash abstracts by id instead of line_num
# TODO: get rid of need for separate hashes of abstract objects and hashes
abstracts_by_ids = {}
abstract_hashes_by_ids = {}
abstracts.hash.keys.sort.each do |key|
  abstract = abstracts.hash[key]
  abstracts_by_ids[abstract.id] = abstract
  abstract_hashes_by_ids[abstract.id] = abstract.to_hash
end

@data[:abstracts] = abstract_hashes_by_ids

File.open("output/#{year}.json", 'w') do |f|
  f.puts JSON.pretty_generate(@data)
end

puts "Data written to output/#{year}.json"

@data[:abstracts] = abstracts_by_ids

hugo = Hugo.new(@data)
hugo.generate
