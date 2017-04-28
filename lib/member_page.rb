# frozen_string_literal: true

require 'scraped'

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    url.to_s[/(\d+)$/, 1]
  end

  field :name do
    info_box.css('h3').text.strip
  end

  field :birth_date do
    dob_str = info_box.xpath('.//span[contains(.,"Born on")]').text
    return if dob_str.to_s.empty?
    dob_obj = Date.parse(dob_str)
    # some only have a day+month, not a year, which Date.parse turns
    # into this year. So skip those.
    return if dob_obj.year == Date.today.year
    dob_obj.to_s
  end

  field :contact_form do
    info_box.xpath('.//a[contains(.,"Contact me")]/@href').text
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
