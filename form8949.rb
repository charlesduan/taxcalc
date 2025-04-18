require 'tax_form'

#
# Sales and dispositions of capital assets
#
class Form8949 < TaxForm

  NAME = '8949'

  def year
    2024
  end

  def initialize(manager, term, reported, forms)
    raise 'Invalid term' unless %w(short long).include?(term)
    raise 'Invalid reported' unless %w(yes no).include?(reported)

    super(manager)
    @term = term
    @reported = reported
    @forms = forms
  end

  attr_accessor :term, :reported

  def compute

    set_name_ssn

    # values is set to a three-element list:
    # - values[0]: Check this box for transactions with basis shown on 1099-B.
    # - values[1]: Check this box for transactions with basis not shown.
    # - values[2]: Number of part.
    values = (@term == 'short') ? %w(A B I) : %w(D E II)

    # Check the box depending on whether basis was reported.
    line[values[@reported == 'yes' ? 0 : 1]] = 'X'

    # Set each line [part].1[column] (e.g., line II.1a)
    p = values[2]
    %w(1a 1b 1c 1d 1e).each do |l|
      pl = "#{p}.#{l}"
      line[pl, :all] = @forms.lines(l)
    end
    line["#{p}.1h", :all] = line["#{p}.1d", :all].zip(
      line["#{p}.1e", :all]
    ).map { |d, e| d - e }
    line["#{p}.2d"] = line["#{p}.1d", :sum]
    line["#{p}.2e"] = line["#{p}.1e", :sum]
    line["#{p}.2h"] = line["#{p}.1h", :sum]
  end

  def self.generate(manager)
    no_forms = true
    fs = manager.forms('1099-B')
    [
      [ 'yes', 'short' ],
      [ 'no', 'short' ],
      [ 'yes', 'long' ],
      [ 'no', 'long' ]
    ].each do |reported, term|
      sfs = fs.select { |f|
        f.line['rep'] == reported && f.line['term'] == term
      }
      unless sfs.empty?
        f = self.new(manager, term, reported, sfs)
        manager.compute_form(f)
        no_forms = false
      end
    end
    manager.no_form('8949') if no_forms
  end

end
