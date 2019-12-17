# regex components that are frequently used
NEWLINE = '\d+\|'.freeze # note: includes the pipe separator
OCRDIGIT = '[\dOlI!TGS]'.freeze # convert to digits using convert_OCR_number
OCRDASH = '[-–.•■]'.freeze
OCRCOLON = '[;:,.]'.freeze

def convert_OCR_number(number)
  number.gsub('O', '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
end

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

