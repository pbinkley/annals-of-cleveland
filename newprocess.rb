#!/usr/bin/env ruby

require 'byebug'

def report_list(list, name)
  lastNumber = 0
  missingNumbers = []
  disorderedNumbers = []
  list.each do |n|
    if n < lastNumber + 1
      # out of order
      disorderedNumbers << n
    elsif n != lastNumber + 1
      missingNumbers +=  (lastNumber + 1 .. n - 1).to_a
    end
    lastNumber = n
  end
  if missingNumbers.empty?
    puts "No missing #{name} numbers"
  else
    puts "Missing #{name} numbers: #{missingNumbers.map { |p| p.to_s }.join(' ')}"
  end
  if disorderedNumbers.empty?
    puts "No disordered #{name} numbers"
  else
    puts "Disordered #{name} numbers: #{disorderedNumbers.map { |p| p.to_s }.join(' ')}"
  end
end

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

pageNumberList = []
breaks.each do |b|
  n = b.match(/\A\n[0-9]*\|([0-9]+).*\z/m)[1].to_i
  pageNumberList << n
  # remove page-break lines from text
  text.sub!(b, "\n")
end

report_list(pageNumberList, 'page')

# Parse entries

entries = text.scan(/^([0-9]+\|[0-9OlI]+ [\-•\.■] .+?\s*\([0-9OlI]+\))\s*$/m)
entryNumberList = []
entries.each do |entry|
  n = entry[0].match(/\A[0-9]+\|([0-9OlI]+).*/)[1].gsub('O', '0').gsub(/[lI]/, '1').to_i
  entryNumberList << n
end

report_list(entryNumberList, 'entry')

# Identify "between" lines, which are either errors or headings

betweens = text.scan(/\([0-9OlI]+\)\s*$(.+?)^[0-9]+\|[0-9OlI]+ [\-•\.■] /m)
# empty lines look like: ["\n11968|\n"]
betweens.reject! { |between| between.first.strip.match /\A[0-9]+\|\z/ }

headings = []
betweens.each do |between|
  headings << between.first.gsub(/[0-9]+\|\n/, '').strip
end
headings.reject! { |heading| heading == '' }

headings.each do |heading|
 # puts heading
end

puts 'Pages: ' + pageNumberList.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Entries: ' + entries.count.to_s
