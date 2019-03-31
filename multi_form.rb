class MultiForm < Array
  def initialize(forms)
    super([ forms ].flatten)
  end

  def lines(*args)
    if args.empty?
      Lines.new(self)
    else
      Lines.new(self)[*args]
    end
  end

  def select(&block)
    MultiForm.new(super(&block))
  end

  def each
    super do |f|
      f.used = true
      yield(f)
    end
  end

  class Lines
    def initialize(mf)
      @mf = mf
    end
    def [](line, type = nil)
      res = @mf.map { |f| f.used = true; f.line[line, type] }
      case type
      when :all then res.flatten
      when :sum then
        if res.empty?
          BlankZero
        else
          res.inject(:+)
        end
      when :present then res.any? && !res.empty?
      else
        if res.any? { |x| x.is_a?(Enumerable) }
          raise "Unexpected array in lines #{line}"
        end
        res
      end
    end
  end

  def export
    each { |f| f.export }
  end

end


