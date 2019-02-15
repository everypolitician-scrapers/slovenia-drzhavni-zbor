#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'date'
require 'pry'
require 'scraped'
require 'scraperwiki'

require_rel 'lib'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :members do
    noko.css('ul.podnaslovUL p.podnaslovOsebaLI a').map do |a|
      {
        sort_name: a.text.tidy,
        source:    a.attr('href'),
      }
    end
  end
end

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'http://www.dz-rs.si/wps/portal/en/Home/ODrzavnemZboru/KdoJeKdo/PoslankeInPoslanci/PoAbecedi'
data = scrape(start => MembersPage).members.map do |mem|
  mem.merge(scrape(mem[:source] => MemberPage).to_h)
end
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i[id party], data)
