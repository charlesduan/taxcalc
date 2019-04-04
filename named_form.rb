class NamedForm < TaxForm
  def initialize(name, data)
    super(data)
    @name = name.to_s
    @exportable = false
  end

  def copy(new_manager)
    super(self.class.new(name, new_manager))
  end

  def name
    @name
  end

  def check_year
    return true
  end

end

