#!/usr/bin/env ruby
# frozen_string_literal: true

require 'nokogiri'
require 'slugify'
require 'json'
require 'yaml'
require 'date'
require 'fileutils'

require './lib/context.rb'
require './lib/entry.rb'
require './lib/page.rb'

require 'byebug'

NWORDREGEX = /([#{78.chr}#{110.chr}])#{105.chr}#{103.chr}#{103.chr}#{101.chr}#{114.chr}/.freeze

newspapers = {
  'L': {
    title: 'Cleveland Morning Leader',
    chronam: 'https://chroniclingamerica.loc.gov/lccn/sn83035143/'
  }
}

# page-level url: https://chroniclingamerica.loc.gov/lccn/sn83035143/1864-01-01/ed-1/seq-2/

doc = File.open('source/1864.html') { |f| Nokogiri::HTML(f) }

FileUtils.mkdir_p './output'

pages = doc.xpath('//div[@class="Page"]')
entries = {}
in_header = false

context = Context.new
context.year = 1864
context.preventry = nil
context.linebuffer = []
context.heading = ''
context.subheading = ''
context.breaks = 0
context.highest = 0
context.issues = {}
context.maxinches = 0
context.maxpage = 0
context.maxcolumn = 0

# classification list
class_lines = []
pages[16..22].each_with_index do |page_ocr, page_index|
  # skip odd pages, which are blank
  next if page_index.odd?
  page = Page.new(context, page_ocr)
  page.lines.each do |line|
    class_lines << line
  end
end

classification = []
line_buffer = []
current_class = nil
previous_class = nil
class_lines.each do |line|
  if line[:text].match(/^[A-Z&, ]+$/)
    if current_class
      c = {headings: [], title: current_class, slug: current_class.gsub('&', 'and').slugify.gsub(/-+/, '')}
      c['line_buffer'] = line_buffer
      classification << c
      line_buffer = []
    end
    current_class = line[:text]
  else
    line_buffer << line[:text]
  end
end
classification.each do |c|
  heading_blocks = c['line_buffer'].join(' ').gsub(/\s+/, ' ').gsub('–', '-').gsub(/(\d)\- (\d)/, '\1-\2').gsub('- ', '').split('. ')

  heading_blocks.each do |block|
    block_parts = block.match(/^(.*)\ (.+?)$/)

    block_entries = block_parts[2].split('-')
    first = block_entries[0].to_i + 1
    last = block_entries.count > 1 ? block_entries[1].to_i : first

    c[:headings] << {
      heading: block_parts[1], 
      upheading: block_parts[1].upcase, 
      slug: block_parts[1].gsub('&', 'and').slugify.gsub(/-+/, ''),
      first: first,
      last: last,
      count: last - first + 1
    }
    puts '  ' + block_parts[1] + ': ' + block_parts[2]
  end
  c.delete 'line_buffer'
end

# abstracts pages
pages[24..384].each do |page_ocr|
  page = Page.new(context, page_ocr)

  page.lines.each do |line|
    # detect headings, see, see also
    is_heading = false
    # ignore dashes at end of line
    if line[:text].match(/^[A-Z\&\ ]*$/)
      context.heading = line[:text]
      context.subheading = ''
      is_heading = true
    end
    if line[:text].match(/^[A-Z\&\ ]*\. See .*$/)
      # TODO: handle see reference
      is_heading = true
    end
    if line[:text].match(/^See also .*$/)
      # TODO: handle see also reference
      is_heading = true
    end
    if context.linebuffer.count > 0
      if context.linebuffer.last.match(/.*\((\d+)\)$/) &&
         line[:text].match(/^[A-Z].*/) && !is_heading
        context.subheading = line[:text]
        is_heading = true
      end
    end
    next if is_heading

    # returns a populated record if the line can be parsed,
    # or an empty one if it can't
    record = Entry.new(context, line[:text], page.seq, line[:index])

    if record.id
      entries[record.id] = record
      context.preventry = record
    end
  end
end

puts 'Breaks: ' + context.breaks.to_s
puts 'Entries: ' + entries.keys.count.to_s
puts 'Highest: ' + context.highest.to_s
puts 'Longest: ' + context.maxinches.to_s
puts 'Max page: ' + context.maxpage.to_s
puts 'Max column: ' + context.maxcolumn.to_s

terms = {}

# index pages - discover index terms matched to entry numbers
pages[398..465].each do |page|
  # seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  lines.each do |line|
    elements = line.match(/^(.*)\, ([0-9\ ]*)$/)
    next unless elements

    term = elements[1]
    slug = term.slugify.gsub(/\-+/, '')
    ids = elements[2].split
    terms[term] = { slug: slug, ids: ids }
    ids.each do |id|
      entries[id.to_i] = Entry.new(context, id.to_i) unless entries[id.to_i]
      entries[id.to_i].add_term(term: term, slug: slug)
    end
  end
end

# output full data dump
File.open('output/data.json', 'w') do |f|
  f.puts JSON.pretty_generate(
    'entries': entries, 'terms': terms, 'issues': context.issues, 'classification': classification
  )
end

# output list of missing ids
missing = 0
File.open('output/missing.txt', 'w') do |f|
  (1..context.highest).each do |key|
    if !entries.keys.include?(key) || !entries[key].init
      f.puts key.to_s
      missing += 1
    end
  end
end
puts 'Missing: ' + missing.to_s

# generate Hugo data
hugodata = {}
headings = []

entries.keys.sort.each do |key|
  entry = entries[key]
  hugodata[entry.heading] = [] unless hugodata[entry.heading]
  hugodata[entry.heading] << entry.to_hash
  headings << entry.heading unless headings.include?(entry.heading)
end

FileUtils.rm_rf('hugo/data/headings')
FileUtils.mkdir_p 'hugo/data/headings'

FileUtils.rm_rf('hugo/content/headings')
FileUtils.mkdir_p 'hugo/content/headings'

FileUtils.rm_rf 'hugo/data/terms'
FileUtils.mkdir_p 'hugo/data/terms'

FileUtils.rm_rf 'hugo/content/terms'
FileUtils.mkdir_p 'hugo/content/terms'

FileUtils.rm_rf 'hugo/data/issues'
FileUtils.mkdir_p 'hugo/data/issues'

FileUtils.rm_rf 'hugo/content/issues'
FileUtils.mkdir_p 'hugo/content/issues'

File.open('hugo/data/headings.json', 'w') do |f|
  f.puts JSON.pretty_generate(headings)
end

File.open('hugo/data/classification.json', 'w') do |f|
  f.puts JSON.pretty_generate(classification)
end

headings.each do |heading|
  slug = heading.to_s.gsub('&', 'and').slugify.gsub('-', '')

  File.open('hugo/data/headings/' + slug + '.json', 'w') do |f|
    f.puts JSON.pretty_generate(
      title: heading, slug: slug, entries: hugodata[heading]
    )
  end
  yaml = { 'title' => heading, 'slug' => slug, 'count' =>
    hugodata[heading].count }.to_yaml
  File.open('hugo/content/headings/' + slug + '.md', 'w') do |f|
    f.puts yaml + "\n---\n\n{{< heading >}}\n"
  end
end

terms.keys.each do |term|
  slug = term.to_s.gsub('&', 'and').slugify.gsub(/-+/, '')
  termentries = []
  terms[term][:ids].each do |id|
    termentries << entries[id.to_i].to_hash
  end
  File.open('hugo/data/terms/' + slug + '.json', 'w') do |f|
    f.puts JSON.pretty_generate(
      title: term, slug: slug, entries: termentries
    )
  end
  yaml = { 'title' => term, 'slug' => slug, 'count' =>
    termentries.count }.to_yaml
  File.open('hugo/content/terms/' + slug + '.md', 'w') do |f|
    f.puts yaml + "\n---\n\n{{< term >}}\n"
  end
end

context.issues.keys.each do |key|
  issue = context.issues[key]

  yaml = { 'title' => key }.to_yaml
  File.open('hugo/content/issues/' + key + '.md', 'w') do |f|
    f.puts yaml + "---\n\n"
    f.puts '<style>
      th, td {width: 12.5%; vertical-align: top}
      .entry {border: 1px solid black;
        margin: 2px;
        padding: 2px;
        text-align: center}
      .inch1 {min-height: 20px}
      .inch2 {min-height: 40px}
      .inch3 {min-height: 60px}
      .inch4 {min-height: 80px}
      .inch5 {min-height: 100px}
      .inch6 {min-height: 120px}
      .inch7 {min-height: 140px}
      .inch8 {min-height: 160px}
      .inch9 {min-height: 180px}
      .inch10 {min-height: 200px}
      .inch11 {min-height: 220px}
      .inch12 {min-height: 240px}
      .inchmore {min-height: 260px}
      </style>'
    (1..4).each do |page|
      pagedata = issue.dig page
      f.puts "<div class=\"page\"><h4>Page #{page} ~ "
      f.puts "<a href='#{newspapers[:L]['chronam']}/#{key}/ed-1/seq-#{page}/'>"
      f.puts 'View at ChronAm</a></h4>'
      f.puts '<table><tr>'
      (1..8).each do |col|
        f.puts "<th>#{col}</th>"
      end
      f.puts '</tr><tr class="column">'
      (1..8).each do |col|
        coldata = pagedata ? pagedata.dig(col) : nil
        f.puts '<td>'
        coldata&.each do |entrykey|
          entry = entries[entrykey]
          f.puts entry.to_html
        end
        f.puts '</td>'
      end
      f.puts '</tr></table></div>'
    end
  end
end
