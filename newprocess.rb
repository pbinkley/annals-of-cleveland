#!/usr/bin/env ruby

require 'byebug'

text = ''
counter = 1
File.readlines(ARGV[0]).each do |line|
  text += "#{counter}|#{line}"
  counter += 1
end

# Identify page breaks so that they can be removed

BREAKREGEX =  /
                \n[0-9]+\|[0-9OlI]+\s*\n[0-9]+\|\n
                [0-9]+\|CLEVELAND\ NEWSPAPER.+?\n[0-9]+\|\n
                [0-9]+\|Abstracts.+?\n[0-9]+\|\n
                [0-9]+\|(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n[0-9]+\|\n
              /x

breaks = text.scan(BREAKREGEX)

pagenumbers = [0]
missingPageNumbers = []
disorderedPageNumbers = []
breaks.each do |b|
  n = b.match(/\A\n[0-9]*\|([0-9]+).*\z/m)[1].to_i
  if n < pagenumbers.last + 1   
    # out of order
    disorderedPageNumbers << n
  elsif n != pagenumbers.last + 1
    missingPageNumbers +=  (pagenumbers.last + 1 .. n - 1).to_a
  end
  pagenumbers <<  n
  # remove page-break lines from text
  text.sub!(b, '')
end

if missingPageNumbers.empty?
  puts 'No missing page numbers'
else
  puts 'Missing page numbers: ' + missingPageNumbers.map { |p| p.to_s }.join(' ')
end


# Parse entries

entries = text.scan(/^([0-9]+\|[0-9OlI]+ [\-•\.■] .+?\s*\([0-9OlI]+\))\s*$/m)

# Identify "between" lines, which are either errors or headings

betweens = text.scan(/\([0-9OlI]+\)\s*$(.+?)^[0-9]+\|[0-9OlI]+ [\-•\.■] /m)
# empty lines look like: ["\n11968|\n"]
betweens.reject! { |between| between.first.strip.match /\A[0-9]+\|\z/ }

headings = []
betweens.each do |between|
  headings << between.first.gsub(/[0-9]+\|\n/, '').strip
end
headings.reject! { |heading| heading == '' }

entries.each do |entry|
#  puts entry.first.match(/^[0-9]+\|[0-9OlI]+/)
  #puts entry.first.split("\n").first
end

headings.each do |heading|
  #puts heading
end

puts 'Pages: ' + pagenumbers.count.to_s
puts 'Missing: ' + missingPageNumbers.count.to_s
puts 'Disordered: ' + disorderedPageNumbers.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Entries: ' + entries.count.to_s
