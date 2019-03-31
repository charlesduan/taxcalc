class BlankNum < DelegateClass(Fixnum)
  def to_s
    self == 0 ? '-' : to_i.to_s
  end

  def -(num)
    res = to_i - num
    if num.is_a?(BlankNum) && res == 0
      return BlankZero
    else
      return res
    end
  end

  def +(num)
    res = to_i + num
    if num.is_a?(BlankNum) && res == 0
      return BlankZero
    else
      return res
    end
  end
end
BlankZero = BlankNum.new(0)



