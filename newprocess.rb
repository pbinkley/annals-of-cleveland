#!/usr/bin/env ruby

require 'date'
require 'damerau-levenshtein'
require 'byebug'

  MONTHS = {
    'Jan.' => 1,
    'Feb.' => 2,
    'Mar.' => 3,
    'Apr.' => 4,
    'May' => 5,
    'June' => 6,
    'July' => 7,
    'Aug.' => 8,
    'Sept.' => 9,
    'Oct.' => 10,
    'Nov.' => 11,
    'Dec.' => 12
  }.freeze


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

def convert_OCR_number(number)
  number.gsub('O', '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
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

entries = text.scan(/^([0-9]+\|[0-9OlI]+\s*[\-•\.■]\s*.+?\s*\([0-9OlI]+\))\s*$/m)
entryNumberList = []
entries.each do |entry|
  n = entry[0].match(/\A[0-9]+\|([0-9OlI]+).*/)[1].gsub('O', '0').gsub(/[lI]/, '1').to_i
  entryNumberList << n
end

report_list(entryNumberList, 'entry')

parsedEntries = 0
year = 1845

entries.each do |entry|
  lines = entry.first.split("\n")
  lines.reject! { |line| line.strip == '' }
  inputLine = lines.first
  line, lineNum, id, half, newspaper, month, day, type, page, column = inputLine.match(
    %r{^(\d+)\|(\d+)(-1/2)?\s       # '1234/123-1/2' line and entry
       [-–.•■]+\ ([a-zA-Z]+)[\.,]?\s   # '- H' newspaper
       (\S+)\s                         #month
       ([\dOlI!TGS]+)[;:,.]+\s?        # '2:' day
       ([a-zA-Z]*)[;:,.]?\s?        # 'ed' type (ed, adv)
       ([\dOlI!TGS]+)[/"']([\dOlI!TGS]+)(.*)$         # '2/3' page and column
    }x
  ).to_a

  parsed = false
  if lineNum
    @day = convert_OCR_number(day)
    month.gsub!(',', '.')
    unless MONTHS[month]
      guess = ''
      guessdistance = 10
      MONTHS.keys.each do |key|
        newGuessDistance = DamerauLevenshtein.distance(month, key, 0)
        if newGuessDistance < guessdistance
          guess = key
          guessdistance = newGuessDistance
        end
      end
      puts "#{lineNum} Guess: #{month} -> #{guess} (#{guessdistance})"
      month = guess
    end
    begin
      date = Date.new(year, MONTHS[month], @day)
    rescue StandardError => e
      puts line
      puts e.message  
    end
    if date
      @lineNum = lineNum.to_i
      @id = id.to_f
      # handle -1/2 suffix on id
      @id += 0.5 if half == '-1/2'
  
  #    @seq = seq
  #    @line = index
      @newspaper = newspaper.to_sym
      @month = MONTHS[month]
      @displaydate = date.strftime('%e %B %Y')
      @formatdate = date.to_s
      @page = convert_OCR_number(page)
      @column = convert_OCR_number(column)
      @type = type
  #    @init = metadata[10]
  #    @heading = @context.heading
  #    @subheading1 = @context.subheading1
  #    @subheading2 = @context.subheading2
  #    @terms = []

      parsed = true
    end
  end
  parsedEntries += 1 if parsed
  puts "bad line: #{inputLine}" unless parsed
end

puts "Parsed: #{parsedEntries}/#{entries.count}"

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
