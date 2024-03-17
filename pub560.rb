require 'tax_form'
require 'form1040_se'

class Pub560Worksheet < TaxForm

  NAME = "Pub. 560 Worksheet"

  def year
    2023
  end

  def initialize(manager, ssn:, contrib_frac:)
    super(manager)
    @ssn = ssn
    @contrib_frac = contrib_frac
  end

  def annual_compensation_limit
    case year
    when 2023 then 330_000
    when 2024 then 345_000
    else raise "Must provide"
    end
  end

  def additions_limit
    case year
    when 2023 then 66_000
    when 2024 then 69_000
    else raise "Must provide"
    end
  end

  def compute

    if interview("Did you have more than 50\% ownership in your businesses?")
      raise "403(b) test not implemented; see memo in Pub. 560 code"
    end

    f1040_se = compute_form('1040 Schedule SE', @ssn)
    unless f1040_se
      raise "Form 1040 Schedule SE failed, despite partnership income"
    end
    line[:ssn] = @ssn
    line[1] = f1040_se.line[:tot_inc]
    line[2] = f1040_se.line[:se_ded]
    line[3] = line[1] - line[2]

    # The formula below implements the Rate Table for Self-Employed.
    line[4] = (@contrib_frac / (1 + @contrib_frac)).round(6)

    line[5] = (line[3] * line[4]).round
    line[6] = (annual_compensation_limit * @contrib_frac).round
    line[7] = [ line[5], line[6] ].min
    line[8] = additions_limit
    #
    # Assume no elective deferrals.
    #
    confirm(
      "#{f1040_se.line[:name]} made no elective deferrals to " \
      "self-employment retirement plans."
    )

    line['21/max_contrib'] = [ line[7], line[8] ].min
  end

end

#
# MEMORANDUM: 403(b) plans and individual 401(k) contributions
#
# Dated: March 16, 2024
#
# IRC 415 sets forth contribution limits for defined contribution plans, which
# include 401(k) and 403(b) plans. Those limits are per-employer, but in certain
# situations multiple employers can be considered a single ``employer'' for
# purposes of the section 415 limits. This occurs when those employers are part
# of a single ``controlled group.''
#
# A controlled group is defined in IRC 1563, subject to the modification of IRC
# 415(h). As modified thereby, two employers may be a controlled group if more
# than 50 percent of ownership is held by a small group of owners. (The
# definition is significantly more involved than this, so see the cited guidance
# for more information.)
#
# For a 403(b) plan, IRS guidance observes that each participant is ``considered
# to have exclusive control over their own annuity contract.'' As a result, if a
# participant also holds ``more than 50 percent'' of ownership in another
# employer under IRC 1563 and 415(h), then the two plans must be aggregated for
# purposes of the IRC 415(c) limits.
#
# The interview question issued by this form ask about the controlled group
# issue described here.
#
# Sources:
# https://www.irs.gov/retirement-plans/issue-snapshot-403b-plan-application-of-irc-section-415c-when-a-403b-plan-is-aggregated-with-a-section-401a-defined-contribution-plan
# https://www.irs.gov/pub/irs-tege/epchd704.pdf
#
