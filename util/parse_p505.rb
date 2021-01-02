#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

doc = URI.open('https://www.irs.gov/publications/p505') do |io|
  Nokogiri::HTML(io)
end

head = doc.at_xpath('//h3[contains(text(), "Tax Rate Schedules")]')
unless head && head.content =~ /(\d{4}) Tax Rate Schedules/
  raise "Could not find tax rate schedules"
end

@tax_year = $1

table_rows = head.xpath(
  './following-sibling::div[@class="informaltable"]/table[2]/tbody/tr'
)

raise "Could not find tax rate tables" unless table_rows

@tables = {
  :single => [],
  :mfj => [],
  :mfs => [],
  :hoh => [],
  :qw => []
}

statuses = {
  'Single' => :single,
  'Head of household' => :hoh,
  'Married filing jointly' => :mfj,
  'Qualifying widow(er)' => :qw,
  'Married filing separately' => :mfs
}

left_status, right_status = nil, nil

table_rows.each do |row|
  cells = row.xpath('./td').map(&:content)

  case cells[0]
  when /filing status is/
    raise "Unexpected number of cells" unless cells.count == 2
    left_status, right_status = cells.map { |cell|
      cell.split(/filing status is/).last.split(' or ').map { |x| statuses[x] }
    }

  when /If line \d+ is/, /^Over/, /^[[:space:]]*$/
    # Ignore
  when /^\$?\d/
    cells = cells.map { |x|
      next nil if x =~ /^[ -]+$/
      x = x.gsub(/[$%,]/, '')
      x =~ /\./ ? x.to_f : x.to_i
    }
    left_status.each do |s|
      @tables[s].push([
        cells[1], cells[2] || 0, (cells[4] * 0.01).round(2), cells[6]
      ])
    end
    right_status.each do |s|
      @tables[s].push([
        cells[8], cells[9] || 0, (cells[11] * 0.01).round(2), cells[13]
      ])
    end
  else
    warn "Unexpected row #{cells[0].inspect}"
  end
end

puts("FilingStatus.set_param(\n  :estimated_tax_brackets,\n")
@tables.each do |k, v|
  puts "  [ # #{k}"
  v.each do |r| puts "    #{r.inspect}," end
  puts "  ],"
end
puts ")"

