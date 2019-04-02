#!/usr/bin/env ruby

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
end

require 'tax_form'
require 'interviewer'
require 'filing_status'

class Biographical < TaxForm

  def name
    'Biographical'
  end

  FIELDS = {
    first_name: 'First name and initial:',
    last_name: 'Last name:',
    ssn: 'Social security number:',
    phone: 'Phone number:',
    spouse_first_name: 'Spouse\'s first name and initial:',
    spouse_last_name: 'Spouse\'s last name:',
    spouse_ssn: 'Spouse\'s social security number:',
    home_address: 'Home address (number and street):',
    apt_no: 'Apartment number:',
    city_zip: 'City, state, and ZIP code:',
    foreign_country: 'Foreign country name:',
    foreign_state: 'Foreign province/state/county:',
    foreign_zip: 'Foreign postal code:',
    birthday: 'Birthday:'
  }

  def compute

    married = interview('Are you married?')
    foreign = interview('Is your residence foreign?')

    FIELDS.each do |l, query|
      next if line[l, :present]

      next if !married && l.to_s =~ /^spouse_/
      next if foreign && l == :city_zip
      next if !foreign && l.to_s =~ /^foreign_/
      line[l] = interview(query)
    end

  end

end

if __FILE__ == $0

  unless ARGV[0]
    warn("Usage: #$0 [FILE]")
    exit 1
  end

  if File.exist?(ARGV[0])
    warn("File #{ARGV[0]} exists; not overwriting")
    exit 1
  end

  m = FormManager.new
  m.compute_form(Biographical)

  open(ARGV[0], 'w') do |f|
    m.export_all(f)
  end

end
