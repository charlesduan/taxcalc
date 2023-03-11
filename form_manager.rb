require_relative 'tax_form'
require_relative 'interviewer'
require 'date'

class FormManager

  include Enumerable

  def initialize(name = nil)
    @name = name
    @forms = {}
    @no_forms = {}
    @ordered_forms = []
    @interviewer = Interviewer.new
    @explain = {}
    @submanagers = {}
    @year = nil
    @compute_stack = []
  end

  attr_reader :name
  attr_reader :interviewer
  attr_accessor :year

  def year
    unless @year
      @year = Date.today.year - 1
      warn("Form Manager #@name: year not set; defaulting to #@year")
    end
    return @year
  end

  def export_all(io = STDOUT, all = false)
    @ordered_forms.each do |f|
      warn("Form #{f.name} was not used") unless f.used
      f.export(io) if all || f.exportable
    end
  end

  def each(&block)
    @ordered_forms.each(&block)
  end

  def list_forms
    @forms.keys.sort.each do |name|
      if @forms[name].is_a?(Enumerable)
        puts "#{name} (#{@forms[name].count})"
      else
        puts "#{name}"
      end
    end
  end

  ########################################################################
  #
  # ADDING AND REMOVING FORMS
  #
  ########################################################################

  #
  # Adds a form to this manager. Checks to ensure that there was no No Form flag
  # for this form, and also that the form belongs to this manager.
  #
  def add_form(form)
    name = form.name.to_s
    if @no_forms.include?(name)
      raise "Adding form #{name} after No Form flag given"
    end
    if form.manager != self
      raise 'Adding form, but wrong manager'
    end

    #
    # Checks the year of the form.
    #
    unless form.is_a?(NamedForm)
      if form.year != self.year
        warn("Form #{name} is for #{form.year}, but manager is #{year}")
      end
    end

    if @forms[name]
      @forms[name] = [ @forms[name], form ].flatten
    else
      @forms[name] = form
    end
    @ordered_forms.push(form)
  end

  # Remove a form from this manager.
  def remove_form(form)
    if @forms[form.name] == form
      @forms.delete(form.name)
    else
      arr = @forms[form.name]
      arr.delete(form)
      case arr.count
      when 0 then @forms.delete(form.name)
      when 1 then @forms[form.name] = arr[0]
      end
    end
    @ordered_forms.delete(form)
  end

  # Flag that no forms with this name will be provided to this manager. This is
  # for error-checking to ensure that a form has not inadvertently been omitted.
  def no_form(form_name)
    @no_forms[form_name.to_s] = 1
  end

  # Copy records of no forms to another manager.
  def copy_no_forms(manager)
    @no_forms.keys.each do |nf|
      manager.no_form(nf)
    end
  end

  # Copy a form, perhaps from another manager.
  def copy_form(other_form)
    new_form = other_form.copy(self)
    new_form.exportable = false
    add_form(new_form)
    return new_form
  end

  # Takes either a Form object or a Form class name. Adds it to this
  # FormManager, and then computes it. Then queries whether the form is needed
  # (using its needed? method), and removes it if not needed.
  #
  # The step of adding and then removing the form is necessary in case computing
  # the form requires computing any subforms that expect the form under
  # computation to be present.
  #
  def compute_form(f, *args, **params)
    case f
    when TaxForm
      form = f
    when Class
      form = f.new(self, *args, **params)
      raise "Invalid type #{f}" unless form.is_a?(TaxForm)
    when String, Numeric
      form = TaxForm.by_name(f.to_s).new(self, *args, **params)
    else
      raise "Unexpected type #{f.class} for compute_form"
    end
    add_form(form)
    form.explain("Computing Form #{form.name} for #{name}")
    @compute_stack.push(form)
    form.compute
    needed = form.needed?
    @compute_stack.pop
    form.explain("Done computing Form #{form.name}")
    unless needed
      form.explain("Removing Form #{form.name} as not needed")
      remove_form(form)
      return nil
    end
    yield(form) if block_given? and form
    return form
  end

  #
  # Continues computation of a form. The parameters are a TaxForm object (since
  # this is a continuation of computation, the object cannot be created) and a
  # symbol representing the name of the computation method (compute_[method]).
  #
  def compute_more(form, method, *args)
    raise "Invalid form for compute_more" unless form.is_a?(TaxForm)
    method = "compute_#{method}".to_sym
    unless form.respond_to?(method)
      raise "Form #{form.name} has no method #{method}"
    end

    form.explain("Computing Form #{form.name} (#{method}) for #{name}")
    @compute_stack.push(form)
    res = form.send(method, *args)
    @compute_stack.pop
    form.explain("Done computing Form #{form.name} (#{method})")
    return res
  end

  # Returns the form that is currently being computed
  def currently_computing
    return @compute_stack.last
  end


  ########################################################################
  #
  # RETRIEVAL OF FORMS
  #
  ########################################################################

  def empty?
    @forms.empty?
  end

  def has_form?(name)
    @forms.include?(name.to_s)
  end

  def all_forms
    @ordered_forms.dup
  end

  #
  # Retrieves a single form with the given name. Produces an error if no form
  # with that name is present or if multiple forms with that name are present. A
  # block may be given, in which case that block will be used to select among
  # multiple matching forms; still, only one form should ultimately match.
  #
  def form(name)
    name = name.to_s
    raise "No form #{name}" unless @forms[name]
    if @forms[name].is_a?(Enumerable)
      forms = @forms[name]
      forms = forms.select { |f| yield(f) } if block_given?
      raise "Multiple forms #{name}" if forms.count != 1
      f = forms.first
    else
      f = @forms[name]
    end
    f.used = true
    return f
  end

  #
  # Retrieves all forms with the given name, as a MultiForm object. Produces a
  # warning if there are no forms with that name and there is no "No Forms" flag
  # for this form name.
  #
  def forms(name)
    name = name.to_s
    unless @forms.include?(name)
      ensure_no_forms(name)
    end
    mf = MultiForm.new(@forms[name] || [])
    if block_given?
      mf = mf.select { |f| yield(f) }
    end
    return mf
  end

  def ensure_no_forms(name)
    unless @no_forms.include?(name)
      warn("Warning: No forms #{name} found for #{@name}.")
      @no_forms[name] = 1
    end
  end

  # Performs a block if the named form exists and returns the result; otherwise
  # performs an alternate block and/or returns an alternate value.
  def with_form(name, otherwise: nil, otherwise_return: nil, required: false)
    if has_form?(name)
      return yield(form(name))
    else
      raise "Form #{name} required but not present" if required
      otherwise_return ||= otherwise.call if otherwise
      return otherwise_return
    end
  end



  ########################################################################
  #
  # DATA INPUT
  #
  ########################################################################

  #
  # Import forms from a file into this FormManager. The specified file is opened
  # and read to create NamedForm objects that are stored to this FormManager.
  # Also, "No Form" directives can be provided.
  #
  def import(file)
    open(file) do |io|
      begin
        until io.eof?
          line = io.gets
          next unless (line && line =~ /\w/)
          next if line =~ /^\s*#/

          unless (line =~ /^((No )?Form|Table) /)
            raise "Invalid start of form"
          end
          type = $1
          name = $'.strip
          case type
          when 'Table'
            import_tabular(name, io)
          when 'No Form'
            @no_forms[name] = 1
            next
          when 'Form'
            new_form = NamedForm.new(name, self)
            new_form.import(io)
            add_form(new_form)
          else
            raise "Unknown form type #{type}"
          end
        end
      rescue => e
        warn(
          "Error during import: #{file}, line #{io.lineno}: #{e}\n" + \
          "#{e.backtrace.join("\n")}\n"
        )
        exit 1
      end
    end
  end

  def import_tabular(name, io = STDIN)
    lines = nil
    io.each do |text|
      break if (text =~ /^\s*$/)
      unless lines
        lines = text.strip.split(/\s+/)
        next
      end
      elts = lines.zip(text.strip.split(/\s+/, lines.count)).map { |l, x|
        Interviewer.parse(l, x)
      }
      raise "Invalid table line #{text}" unless lines.count == elts.count

      new_form = NamedForm.new(name, self)
      lines.zip(elts).each do |l, e|
        new_form.line[l] = e
      end
      add_form(new_form)
    end
  end

  def interview(prompt, form = nil)
    @interviewer.ask(prompt, form)
  end

  def confirm(prompt, form)
    @interviewer.confirm(prompt, form)
  end

  ########################################################################
  #
  # FORM EXPLAINING
  #
  ########################################################################

  #
  # Request that forms of a given name display explanations during computation.
  # This affects the form's +explain+ method.
  #
  def explain(form)
    @explain[form.to_s] = true
  end

  #
  # Test whether the given form should have explanations printed out.
  #
  def explaining?(form)
    @explain.include?(form.name.to_s)
  end

  ########################################################################
  #
  # SUBMANAGERS
  #
  ########################################################################

  #
  # Add a submanager.
  # 
  def add_submanager(name, manager)
    unless [ :last_year, :spouse, :unamended ].include?(name)
      warn("Unexpected submanager name #{name}")
    end
    @submanagers[name] = manager
  end

  #
  # Add a submanager and read a file.
  #
  def add_submanager_from_file(name, file, sub_name = nil)
    sub_name = "#@name, submanager #{name}" unless sub_name
    manager = FormManager.new(sub_name)
    manager.import(file)
    add_submanager(name, manager)
  end

  #
  # Use a submanager.
  #
  def submanager(name)
    @submanagers[name]
  end


end

