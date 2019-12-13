#!/usr/bin/env ruby

require 'date'
require 'damerau-levenshtein'
require 'htmlentities'
require 'slugify'

require 'byebug'

coder = HTMLEntities.new


def report_list(list, name)
  lastNumber = 0
  missingNumbers = []
  disorderedNumbers = []
  list.each do |n|
    if n <= lastNumber
      # out of order
      disorderedNumbers << n
    elsif n != lastNumber + 1
      missingNumbers +=  (lastNumber.to_i + 1 .. n.to_i - 1).to_a
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


# regex components that are frequently used
newLine = '\d+\|' # note: includes the pipe separator
ocrDigit = '[\dOlI!TGS]' # convert to digits using convert_OCR_number
ocrDash = '[-–.•■]'
ocrColon = '[;:,.]'

def convert_OCR_number(number)
  number.gsub('O', '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
end

text = ''
counter = 1
File.readlines(ARGV[0]).each do |line|
  text += "#{counter}|#{line}"
  counter += 1
end

text = coder.decode(text) # decode html entities

# Identify page breaks so that they can be removed

BREAKREGEX =  /
                \n#{newLine}#{ocrDigit}+\s*\n#{newLine}\n
                #{newLine}CLEVELAND\ NEWSPAPER.+?\n#{newLine}\n
                #{newLine}Abstracts.+?\n#{newLine}\n
                #{newLine}(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n#{newLine}\n
              /x

breaks = text.scan(BREAKREGEX)

pageNumberList = []
breaks.each do |brk|
  entryNum = brk.match(/\A\n#{newLine}(\d+).*\z/m)[1].to_i
  pageNumberList << entryNum.to_i
  # remove page-break lines from text
  text.sub!(brk, "+++ page #{entryNum}\n")
end

pages = text.scan(/^(#{newLine}\+\+\+.*)$/)

report_list(pageNumberList, 'page')

File.open("text-without-breaks.txt", "w") { |f| f.puts text }








# Parse entries

entries = text.scan(/^(#{newLine}#{ocrDigit}+\s*#{ocrDash}\s*.+?\s*\(#{ocrDigit}+\))\s*$/m)
entryNumberList = []


parsedEntries = 0
year = 1845

# parse metadata from first line of each entry
# canonical form:
# 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
entries.each do |entry|
  lines = entry.first.split("\n")
  # remove blank lines
  lines.reject! { |line| line.match (/\A#{newLine}\z/) }
  inputLine = lines.first
  metadata = Metadata.new(inputLine)

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
      # puts "#{lineNum} Guess: #{month} -> #{guess} (#{guessdistance})"
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
      entryNumberList << @id
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
      # save normalized version of first line
      lines[0] = "#{lineNum}|#{id} - #{newspaper} #{month} #{@day}#{('; ' + @type) if !@type.empty?}:#{@page}/#{@column}#{remainder}"
    end
  end
  parsedEntries += 1 if parsed
  puts "bad line: #{inputLine}" unless parsed
end

puts "Parsed: #{parsedEntries}/#{entries.count}"

report_list(entryNumberList, 'entry')








# Identify "between" lines, which are either errors or headings

betweens = []
text.scan(/\(#{ocrDigit}+\)\s*$(.+?)^#{newLine}#{ocrDigit}+ #{ocrDash} /m).map { |between| betweens += between[0].split("\n") }

# empty lines look like: ["\n11968|\n"]
betweens.reject! { |between| between == '' || between.match(/\A#{newLine}\z/) || between.match(/\A#{newLine}\+\+\+/) }

headings = []
betweens.each do |between|
  headings << between.gsub(/#{newLine}\n/, '').strip
end

seealsos = []

headings.each do |heading|
  text = heading.match(/\A#{newLine}(.*)/)[1]
  if text.match(/^===/)
    # TODO: handle text note
  elsif text.match(/^\+/)
    # text inserted by editor
    text = text.gsub(/^\++ /, '')
    if text.match(/^\+\+\+ /)
      context.subheading2 = text
    elsif text.match(/^\+\+ /)
      context.subheading1 = text
      context.subheading2 = ''
    else
      context.text = text
      context.subheading1 = ''
      context.subheading2 = ''
    end
  elsif text.match(/^[A-Z\&\'\,\ ]*[\.\-\ ]*$/)
    context.text = text.sub(/[\.\-\ ]*$/, '')
    context.subheading1 = ''
    context.subheading2 = ''
    is_heading = true
  elsif text.match(/^[A-Z\&\'\,\ ]*\. See .*$/)
    # TODO: handle see reference
    # e.g. "ABANDONED CHILDREN. See Children"
    is_heading = true
  elsif text.match(/^.* - See .*$/)
    # TODO: handle see entry reference
    # e.g. "ABANDONED CHILDREN. See Children"
    is_heading = true
  elsif text.match(/^See also .*$/)
    # e.g. "See also Farm Products"
    seealso = text.sub('See also ', '')
    seealso.split(';').each do |text|
      text.strip!
      if text[0].match(/[A-Z]/)
        parts = text.split('-')
        obj = {'text' => parts[0].to_s.strip, 'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '')}
        obj['subheading'] = parts[1].to_s.strip
        seealsos << obj
      else
        # generic entry like "names of animals"
        seealsos << {generic: text}
      end
    end
    is_heading = true
    byebug
  end
end

puts 'Pages: ' + pageNumberList.count.to_s
puts 'Headings: ' + headings.count.to_s
puts 'Entries: ' + entries.count.to_s
