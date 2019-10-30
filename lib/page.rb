# frozen_string_literal: true

# A page of OCR text, with methods to divide into lines
class Page
  attr_reader :lines, :seq

  def initialize(context, page_ocr)
    @lines = []
    @line_numbers = []
    in_header = true
    @seq = page_ocr.xpath('./@id').first.text
    page_text = page_ocr.xpath('./p[@class="Text"]').first.text
                 .gsub(NWORDREGEX, '\1****r')
    lines = page_text.split(/\n+/)
    lines.each_with_index do |line, index|
        # fix ocr oddities: ' - - -' etc.
        stripped_line = line.gsub(/^[ -]*/, '').gsub(/[ -]*$/, '')
        next if stripped_line == ''

        # detect and ignore page headers
        if in_header
            unless stripped_line.match(/^\d*$/) ||
                 stripped_line.match(/^CLEVELAND NEWSPAPER DIGEST.*/) ||
                 stripped_line.match(/^Abstracts \d.*/) ||
                 stripped_line.match(/.*\(Co[nr]t'd\ ?\)[\.\-\ ]*/) ||
                 stripped_line.match(/CLASSIFICATION LISTS.*/) ||
                 stripped_line.match(/^[IWV]+$/)
            in_header = false
            end
        end
        next if in_header
        stripped_line += '-' if line[-1] == '-'
        @lines << {index: index, text: stripped_line}
    end
  end
end
