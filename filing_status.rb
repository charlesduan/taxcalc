class FilingStatus

  def initialize(name)
    @name = name
    @params = {}
    All[name] = self
  end

  attr_reader :name

  def method_missing(name, *args)
    super(name, *args) unless @params.include?(name.to_s)

    val = @params[name.to_s]
    case val
    when :err then raise "#{name} not implemented for filing status #{@name}"
    when :half_mfj then MarriedFilingJointly.send(name, *args) / 2
    when Symbol then FilingStatus.for(val.to_s).send(name, *args)
    when Proc then val.call(*args)
    else val
    end
  end

  All = {}

  Single = FilingStatus.new('single')
  MarriedFilingJointly = FilingStatus.new('mfj')
  MarriedFilingSeparately = FilingStatus.new('mfs')
  HeadOfHousehold = FilingStatus.new('hoh')
  QualifyingWidow = FilingStatus.new('qw')

  def set_param(key, val = nil, &block)
    @params[key] = block || val
  end

  def is(expected)
    if expected.is_a?(Array)
      return expected.any? { |x| is(x) }
    else
      return @name == expected
    end
  end

  def visit(visitor, *args)
    visitor.send(@name, *args)
  end

  def halve_mfs(amt)
    if is('mfs')
      return amt / 2
    else
      return amt
    end
  end

  def self.for(name)
    raise "Invalid filing status #{name}" unless All[name]
    All[name]
  end

  def self.set_param(key, single, mfj, mfs, hoh, qw)
    Single.set_param(key, single)
    MarriedFilingJointly.set_param(key, mfj)
    MarriedFilingSeparately.set_param(key, mfs)
    HeadOfHousehold.set_param(key, hoh)
    QualifyingWidow.set_param(key, qw)
  end

end


class FilingStatusVisitor
end

