require 'tax_form'

class Interviewer

  def initialize
    @fh = nil
    @answers = {}
  end

  attr_reader :answers

  def file=(file)
    last_q = nil
    if File.exist?(file)
      open(file) do |fh|
        fh.each do |line|
          line = line.chomp
          next if line == ''
          if line =~ /^\s+/
            if @answers.include?(last_q)
              warn("Duplicate interview question: #{last_q}")
            end
            @answers[last_q] = Interviewer.parse(last_q, line.strip)
          else
            last_q = line
          end
        end
      end
    end
    @fh = open(file, 'a')
  end

  def persist(prompt, answer)
    if @fh
      @fh.puts prompt
      @fh.puts "\t#{answer}"
      @fh.puts
    end
  end

  def ask(prompt, form = nil)
    return @answers[prompt] if @answers.include?(prompt)
    puts ""
    if form
      puts "  For form #{form.name} for #{form.manager.name}:"
    end
    puts "    #{prompt}"
    resp = STDIN.gets.strip
    persist(prompt, resp)
    return answer(prompt, resp)
  end

  def answer(prompt, resp)
    parsed_resp = Interviewer.parse(prompt, resp)
    return if @answers[prompt] == parsed_resp
    @answers[prompt] = parsed_resp
    return parsed_resp
  end

  def self.parse(question, data)
    if question =~ /\?$/
      return true if data =~ /^y(es)?/i
      return false if data =~ /^no?/i
      raise "Invalid answer to yes-no question"
    end

    case data
    when '-' then BlankZero
    when /^-?\d+$/ then data.to_i
    when /^-?\d*\.\d*$/ then data.to_f
    when /^\[\s*(.*)\s*\]$/
      $1.split(/,\s*/).map { |x| parse(question, x.strip) }
    else data
    end
  end


end
