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
    status: "Filing status (#{FilingStatus::All.keys.join(', ')}):",
    first_name: 'First name and initial:',
    last_name: 'Last name:',
    ssn: 'Social security number:',
    ssn_1: 'Social security number:',
    ssn_2: 'Social security number:',
    ssn_3: 'Social security number:',
    phone: 'Phone number:',
    spouse_first_name: 'Spouse\'s first name and initial:',
    spouse_last_name: 'Spouse\'s last name:',
    spouse_ssn: 'Spouse\'s social security number:',
    spouse_ssn_1: 'Spouse\'s social security number:',
    spouse_ssn_2: 'Spouse\'s social security number:',
    spouse_ssn_3: 'Spouse\'s social security number:',
    home_address: 'Home address (number and street):',
    apt_no: 'Apartment number:',
    city_zip: 'City, state, and ZIP code:',
    foreign_country: 'Foreign country name:',
    foreign_state: 'Foreign province/state/county:',
    foreign_zip: 'Foreign postal code:',
  }

  def compute

    status = nil
    FIELDS.each do |l, query|
      next if line[l, :present]

      case l.to_s
      when 'status'
        until FilingStatus::All[status]
          if status
            puts "Invalid status #{status}"
            manager.interviewer.unask(query)
          end

          status = interview(query)
        end
        line[:status] = status
        next
      when 'spouse_ssn'
        next unless %w(mfj mfs).include?(status)
      when /^spouse_/
        next unless status == 'mfj'
      when /^foreign_/
        next if (line[:city_zip] || '') =~ / [A-Z][A-Z],? \d{5}$/
      end
      line[l] = interview(query)
      if l.to_s =~ /ssn$/
        line[l] = line[l].to_s.gsub(/\D+/, '').insert(5, '-').insert(3, '-')
        line["#{l}_1"] = line[l][0..2]
        line["#{l}_2"] = line[l][4..5]
        line["#{l}_3"] = line[l][7..10]
      end
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
