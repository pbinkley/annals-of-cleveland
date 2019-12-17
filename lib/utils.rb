# regex components that are frequently used
NEWLINE = '\d+\|'.freeze # note: includes the pipe separator
OCRDIGIT = '[\dOlI!TGS]'.freeze # convert to digits using convert_OCR_number
OCRDASH = '[-–.•■]'.freeze
OCRCOLON = '[;:,.]'.freeze

def convert_OCR_number(number)
  number.gsub('O', '0').gsub(/[lI!T]/, '1').gsub(/[GS]/, '5').to_i
end

