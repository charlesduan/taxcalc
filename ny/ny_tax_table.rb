module NYTaxTable

  #
  # These tables are for 2023.
  #
  RATES = {
    :mfj => [
      [ 0, 17_150, 0, 4, 0 ],
      [ 17_150, 23_600, 686, 4.5, 17_150 ],
      [ 23_600, 27_900, 976, 5.25, 23_600 ],
      [ 27_900, 161_550, 1_202, 5.5, 27_900 ],
      [ 161_550, 323_200, 8_553, 6, 161_550 ],
      [ 323_200, 2_155_350, 18_252, 6.85, 323_200 ],
      [ 2_155_350, 5_000_000, 143_754, 9.65, 2_155_350 ],
      [ 5_000_000, 25_000_000, 418_263, 10.3, 5_000_000 ],
      [ 25_000_000, nil, 2_478_263, 10.9, 25_000_000 ],
    ],
  }

  def compute_tax(amount, status)
    rates = RATES[status.to_sym]
    raise "No rates given for #{status}" unless rates
    rates.each do |min_amt, max_amt, base, pct, excess|
      next unless amount > min_amt
      next unless max_amt.nil? || amount <= max_amt
      return base + pct / 100.0 * (amount - excess)
    end
    raise "No matching tax bracket found"
  end
end
