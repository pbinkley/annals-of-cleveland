# frozen_string_literal: true

require 'slugify'
require 'json'
require 'yaml'
require 'date'
require 'fileutils'
require './lib/metadata.rb'
require 'active_support/core_ext/hash/keys.rb'

require 'byebug'

class Hugo

  def initialize(data)
    @data = data
    @abstracts = @data[:abstracts]
    @headings = @data[:headings]
    @terms = @data[:terms]
    @issues = @data[:issues]
    @hugodata = {}
  end

  def generate_heading(heading, parents, path)
    FileUtils.mkdir_p(path)
    slug = heading[:text].slugify.gsub('-', '')
    File.open('hugo/data/headings/' + slug + '.json', 'w') do |f|
      f.puts JSON.pretty_generate(
        title: heading[:text], slug: slug, abstracts: heading[:abstracts]
      )
    end
    abstracts = heading[:abstracts].map do |abstract_id|
      @abstracts[abstract_id].to_hash
    end
    children = heading[:children].to_a
    yaml =
      {
        'title' => heading[:text],
        'slug' => slug,
        'count' => heading[:abstracts].count,
        'seealso' => @seealsos[heading],
        'children' => children,
        'parents' => parents,
        'abstracts' => abstracts
      }
      .deep_stringify_keys
      .to_yaml
    File.open(path + slug + '.md', 'w') do |f|
      f.puts yaml + "\n---\n\n{{< heading >}}\n"
    end
    path += slug + '/'
    parents << heading[:text]
    children.each do |child|
      generate_heading(child, parents.dup, path)
    end
  end

  def generate
    @hugo_headings = []

    # dummy
    @seealsos = {}

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
      f.puts JSON.pretty_generate(@headings)
    end

    @headings.keys.each do |key|
      generate_heading(@headings[key], [], 'hugo/content/headings/')
    end

    @terms.keys.each do |term|
      slug = term.to_s.gsub('&', 'and').slugify.gsub(/-+/, '')
      term_abstracts = []
      @terms[term][:ids].each do |id|
        term_abstracts << @abstracts[id].to_hash if @abstracts[id]
      end
      File.open('hugo/data/terms/' + slug + '.json', 'w') do |f|
        f.puts JSON.pretty_generate(
          title: term, slug: slug, abstracts: term_abstracts
        )
      end
      yaml = { 'title' => term, 'slug' => slug, 'count' =>
        term_abstracts.count, 'abstracts' => term_abstracts }
             .deep_stringify_keys
             .to_yaml

      File.open('hugo/content/terms/' + slug + '.md', 'w') do |f|
        f.puts yaml + "\n---\n\n{{< term >}}\n"
      end
    end

    @issues.keys.each do |key|
      issue = @issues[key]

      yaml = { 'title' => key }.to_yaml
      File.open('hugo/content/issues/' + key + '.md', 'w') do |f|
        f.puts yaml + "---\n\n"
        f.puts '<style>
          th, td {width: 12.5%; vertical-align: top}
          td {height: 250px}
          .abstract {border: 1px solid black;
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
          f.puts "<a href='#{NEWSPAPERS[:L]['chronam']}/#{key}/ed-1/seq-#{page}/'>"
          f.puts 'View at ChronAm</a></h4>'
          f.puts '<table><tr>'
          (1..8).each do |col|
            f.puts "<th>#{col}</th>"
          end
          f.puts '</tr><tr class="column">'
          (1..8).each do |col|
            coldata = pagedata ? pagedata.dig(col) : nil
            f.puts '<td>'
            coldata&.each do |abstractkey|
              abstract = @abstracts[abstractkey]
              f.puts abstract.to_html
            end
            f.puts '</td>'
          end
          f.puts '</tr></table></div>'
        end
      end
    end
  end

end
