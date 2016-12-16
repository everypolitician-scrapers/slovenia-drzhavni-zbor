#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'

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

def dob_from(str)
  return if str.to_s.empty?
  Date.parse(str.sub('Born on ','')).to_s
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('ul.podnaslovUL p.podnaslovOsebaLI a').each do |a|
    scrape_person(a.text.tidy, URI.join(url, a.attr('href')))
  end
end

def scrape_person(sortname, url)
  noko = noko_for(url)

  info_box = noko.css('table.panelGrid')
  panel_box = noko.css('.panelBox100')

  party_data = panel_box.css('a[href*="PoslanskaSkupina"]').text
  party_id, party = party_data.match(/(.*?) - (.*?) \(.*?\)/).captures rescue binding.pry
  party.sub!(/\s*Deputy Group\s*/, '')

  data = { 
    id: url.to_s[/(\d+)$/, 1],
    name: info_box.css('h3').text.strip,
    sort_name: sortname,
    birth_date: dob_from(info_box.xpath('.//span[contains(.,"Born on")]').text),
    contact_form: info_box.css('a.outputLinkEx[href*="dz-rs"]/@href').text,
    constituency: panel_box.xpath('.//span[contains(.,"Electoral district")]/text()').text.sub(': ','').strip,
    party: party,
    party_id: party_id,
    image: info_box.css('img.graphicImageEx/@src').text,
    term: '7',
    source: url.to_s,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_list('http://www.dz-rs.si/wps/portal/en/Home/ODrzavnemZboru/KdoJeKdo/PoslankeInPoslanci/PoAbecedi')
