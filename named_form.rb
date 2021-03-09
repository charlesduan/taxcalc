class NamedForm < TaxForm
  def initialize(name, manager)
    super(manager)
    @name = name.to_s
    @exportable = false
  end

  def copy(new_manager)
    super(self.class.new(name, new_manager))
  end

  NAME = 'Named Form (This Should Never Appear)'

  def name
    @name
  end

  def check_year
    return true
  end

end

