# frozen_string_literal: true

require 'colorize'
require 'slugify'
require 'linguistics'
require 'linguistics/en'
require 'linguistics/en/titlecase'

Linguistics.use(:en)

# regex components that are frequently used
NEWLINE = '\d+\|' # note: includes the pipe separator
OCRDIGIT = '[\dCOlI!TGS]' # convert to digits using convert_ocr_number
OCRDASH = '[-–.•■]'
OCRCOLON = '[;:,.]'

NWORDREGEX = /([#{78.chr}#{110.chr}])#{105.chr}#{103.chr}#{103.chr}#{101.chr}#{114.chr}/.freeze

def convert_ocr_number(number)
  number.gsub(/CO/, '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
end

def report_list(list, name)
  list.sort!
  last_number = 0
  missing_numbers = []
  disordered_numbers = []
  list.each do |n|
    if n <= last_number
      # out of order
      disordered_numbers << n
    elsif n != last_number + 1
      missing_numbers += (last_number.to_i + 1..n.to_i - 1).to_a
    end
    last_number = n
  end
  if missing_numbers.empty?
    puts "No missing #{name} numbers".green
  else
    puts "Missing #{name} numbers: \
#{missing_numbers.map(&:to_s).join(' ')}".red
  end
  if disordered_numbers.empty?
    puts "No disordered #{name} numbers".green
  else
    puts "Disordered #{name} numbers: \
#{disordered_numbers.map(&:to_s).join(' ')}".red
  end
end

def titlecase(str)
  if !str.empty?
    str.gsub('&', 'and').downcase.en.titlecase
  else
    str
  end
end

def filenamify(str)
  filename = str.slugify.gsub(/-+/, '-').gsub(/\A-|-\z/, '')
  filename.length > 100 ? filename[0..99] : filename
end
