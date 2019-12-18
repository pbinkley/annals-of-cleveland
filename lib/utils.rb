# frozen_string_literal: true

# regex components that are frequently used
NEWLINE = '\d+\|' # note: includes the pipe separator
OCRDIGIT = '[\dOlI!TGS]' # convert to digits using convert_ocr_number
OCRDASH = '[-–.•■]'
OCRCOLON = '[;:,.]'

def convert_ocr_number(number)
  number.gsub('O', '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
end

def report_list(list, name)
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
    puts "No missing #{name} numbers"
  else
    puts "Missing #{name} numbers: \
#{missing_numbers.map(&:to_s).join(' ')}"
  end
  if disordered_numbers.empty?
    puts "No disordered #{name} numbers"
  else
    puts "Disordered #{name} numbers: \
#{disordered_numbers.map(&:to_s).join(' ')}"
  end
end
