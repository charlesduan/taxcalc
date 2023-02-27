require 'tax_form'
require 'form1040_se'

class Pub560Worksheet < TaxForm

  NAME = "Pub. 560 Worksheet"

  def year
    2022
  end

  def initialize(manager, ssn:, contrib_frac:)
    super(manager)
    @ssn = ssn
    @contrib_frac = contrib_frac
  end

  def compute
    f1040_se = compute_form('1040 Schedule SE', @ssn)
    line[1] = f1040_se.line[:tot_inc]
    line[2] = f1040_se.line[:se_ded]
    line[3] = line[1] - line[2]
    line[4] = (@contrib_frac / (1 + contrib_frac)).round(6)
    line[5] = (line[3] * line[4]).round
    line[6] = (305_000 * @contrib_frac).round
    line[7] = [ line[5], line[6] ].min
    line[8] = 61_000
    #
    # Assume no elective deferrals.
    #
    line['21/max_contrib'] = [ line[7], line[8] ].min
  end

end
