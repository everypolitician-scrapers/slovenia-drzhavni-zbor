#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'date'
require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

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

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    url.to_s[/(\d+)$/, 1]
  end

  field :name do
    info_box.css('h3').text.strip
  end

  field :birth_date do
    dob_from(info_box.xpath('.//span[contains(.,"Born on")]').text)
  end

  field :contact_form do
    info_box.css('a.outputLinkEx[href*="dz-rs"]/@href').text
  end

  field :constituency do
    panel_box.xpath('.//span[contains(.,"Electoral district")]/text()').text.sub(': ', '').strip
  end

  field :party do
    party_data.last
  end

  field :party_id do
    party_data.first
  end

  field :image do
    info_box.css('img.graphicImageEx/@src').text
  end

  field :term do
    '7'
  end

  private

  def dob_from(str)
    return if str.to_s.empty?
    Date.parse(str.sub('Born on ', '')).to_s
  end

  def info_box
    noko.css('table.panelGrid')
  end

  def panel_box
    noko.css('.panelBox100')
  end

  def party_data
    party_data = panel_box.css('a[href*="PoslanskaSkupina"]').text
    party_id, party = party_data.match(/(.*?) - (.*?) \(.*?\)/).captures rescue binding.pry
    party.sub!(/\s*Deputy Group\s*/, '')
    [party_id, party]
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
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
