require './lib/heading.rb'
require 'rspec'
require 'byebug'

describe Heading do
  it 'parses a clean 1864 heading' do
    heading = Heading.new('10|ADVERTISING & ADVERTISERS -', 1, 1864)
    expect(heading.text).to eq('Advertising and Advertisers')
    expect(heading.type).to eq('heading')
    expect(heading.slug).to eq('advertising-and-advertisers')
  end
  it 'parses a clean 1864 see reference' do
    heading = Heading.new('10|ABANDONED CHILDREN. See Children', 1, 1864)
    expect(heading.text).to eq('Abandoned Children')
    expect(heading.type).to eq('see')
    expect(heading.targets.first[:heading]).to eq('Children')
  end
  it 'parses a clean 1864 see also reference' do
    heading = Heading.new('10|See also Farm Products', 1, 1864)
    expect(heading.text).to eq('See also Farm Products')
    expect(heading.type).to eq('see also')
    expect(heading.targets.first[:text]).to eq('Farm Products')
  end
  it 'parses a clean 1864 subheading1' do
    heading = Heading.new('10|Book Stores', 1, 1864)
    expect(heading.text).to eq('Book Stores')
    expect(heading.type).to eq('subheading1')
    expect(heading.slug).to eq('book-stores')
  end
  it 'parses a clean 1864 subheading2' do
    heading = Heading.new('10|(Bandits & Guerillas)', 1, 1864)
    expect(heading.text).to eq('Bandits and Guerillas')
    expect(heading.type).to eq('subheading2')
    expect(heading.slug).to eq('bandits-and-guerillas')
  end
  it 'parses a clean 1864 see abstract' do
    heading = Heading.new('10|H Feb. 28:3/3 - See Streets', 1, 1864)
    expect(heading.abstract.normalized_metadata).to eq('H Feb. 28:3/3')
    expect(heading.type).to eq('see abstract')
    expect(heading.targets.first).to eq('Streets')
  end
end
