#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'

require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_list(h)
  noko = noko_for(h[:source])
  noko.css('#%s' % h[:after]).xpath('.//preceding::*').remove
  noko.css('#%s' % h[:before]).xpath('.//following::*').remove

  noko.css('h3').each do |section|
    party = section.css('.mw-headline').text.gsub(/\(\d+\)/,'').tidy
    section.xpath('.//following-sibling::table[1]//tr[.//td[2]]').each do |tr|
      td = tr.css('td')

      # TODO pick up the start/end dates
      data = { 
        name: td[1].text.tidy,
        wikiname: td[1].xpath('.//a[not(@class="new")]/@title').text,
        party: party,
        area: td[2].text.tidy,
        area_wikiname: td[2].xpath('.//a[not(@class="new")]/@title').text,
        notes: td[4].text.tidy,
        term: h[:term],
      }
      data[:area] = 'List' if data[:area].to_s.empty?
      ScraperWiki.save_sqlite([:name, :party, :term, :area], data)
      end
  end
end

scrape_list({
  source: 'https://en.wikipedia.org/wiki/50th_New_Zealand_Parliament',
  term: 50,
  after: 'Members',
  before: 'Parliamentary_business',
})
