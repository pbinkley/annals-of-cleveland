require './lib/utils.rb'
require 'rspec'
require 'byebug'

describe Heading do
  it 'parses a clean 1864 heading' do
    heading = Heading.new('10|ADVERTISING & ADVERTISERS -', 1, 1864, [])
    expect(heading.text).to eq('Advertising and Advertisers')
    expect(heading.type).to eq('heading')
    expect(heading.slug).to eq('advertising-and-advertisers')
  end
end