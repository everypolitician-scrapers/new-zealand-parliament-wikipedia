#!/bin/env ruby
# encoding: utf-8

require 'date'
require 'nokogiri'
require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def date_from(str)
  return if str.to_s.empty?
  Date.parse(str).to_s rescue nil
end


def table_per_party(h)
  noko = noko_for(h[:source])
  noko.css('#%s' % h[:after]).xpath('.//preceding::*').remove
  noko.css('#%s' % h[:before]).xpath('.//following::*').remove
  noko.css('h3').each do |section|
    party = section.css('.mw-headline').text.gsub(/\(\d+\)/,'').tidy
    next if party == 'Overview'
    section.xpath('.//following-sibling::table[1]//tr[.//td[2]]').each do |tr|
      td = tr.css('td')
      notes = td[4].text.tidy rescue ''
      # TODO pick up the start/end dates
      data = {
        name: td[1].text.tidy,
        wikiname: td[1].xpath('.//a[not(@class="new")]/@title').text,
        party: party,
        area: td[2].text.tidy,
        area_wikiname: td[2].xpath('.//a[not(@class="new")]/@title').text,
        notes: notes,
        term: h[:term],
      }
      data[:area] = 'List' if data[:area].to_s.empty?
      puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
      ScraperWiki.save_sqlite([:name, :party, :term, :area], data)
    end
  end
end

def single_table(h)
  noko = noko_for(h[:source])
  noko.css('#%s' % h[:after]).xpath('.//preceding::*').remove
  noko.css('#%s' % h[:before]).xpath('.//following::*').remove
  noko.xpath('.//table//tr[td]').each do |tr|
    td = tr.css('td')
    data = {
      name: td[2].css('.vcard').text.tidy,
      wikiname: td[2].xpath('.//a[not(@class="new")]/@title').text,
      sort_name: td[2].css('span/@data-sort-value').text,
      party: td[1].text.tidy,
      party_wikiname: td[1].xpath('.//a[not(@class="new")]/@title').text,
      area: td[3].css('a').map(&:text).map(&:tidy).first || tds[3].text.tidy,
      area_wikiname: td[3].xpath('.//a[not(@class="new")]/@title').text,
      term: h[:term],
    }
    data[:area] = 'List' if data[:area].to_s.downcase.include? 'party list'
    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite([:name, :party, :term, :area], data)
  end
end

def single_table_changes(h)
  noko = noko_for(h[:source])
  noko.css('#%s' % h[:after]).xpath('.//preceding::*').remove
  noko.css('#%s' % h[:before]).xpath('.//following::*').remove
  noko.xpath('.//table//tr[td[2]]').each do |tr|
    td = tr.css('td')
    # TODO set an end date on the prior MP
    data = {
      name: td[2].text.tidy,
      wikiname: td[2].xpath('.//a[not(@class="new")]/@title').text,
      party: td[1].text.tidy,
      party_wikiname: td[1].xpath('.//a[not(@class="new")]/@title').text,
      start_date: td[3].css('.sortkey').text.sub(/^0*/,'').sub('-0000',''),
      area: td[4].text.tidy,
      area_wikiname: td[4].xpath('.//a[not(@class="new")]/@title').text,
      term: h[:term],
    }
    next if data[:name].include? '(vacant)'
    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite([:name, :party, :term, :area], data)
  end
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil

table_per_party({
  source: 'https://en.wikipedia.org/wiki/50th_New_Zealand_Parliament',
  term: 50,
  after: 'Members',
  before: 'Parliamentary_business',
})

table_per_party({
  source: 'https://en.wikipedia.org/wiki/49th_New_Zealand_Parliament',
  term: 49,
  after: 'Members_of_the_49th_New_Zealand_Parliament',
  before: 'By-elections_during_49th_Parliament',
})

single_table({
  source: 'https://en.wikipedia.org/wiki/48th_New_Zealand_Parliament',
  term: 48,
  after: 'Members_of_the_48th_Parliament',
  before: 'Changes_during_parliamentary_term',
})

single_table_changes({
  source: 'https://en.wikipedia.org/wiki/48th_New_Zealand_Parliament',
  term: 48,
  after: 'Changes_during_parliamentary_term',
  before: 'See_also',
})

