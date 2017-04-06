require 'tax_form'

class Interviewer

  def initialize
    @fh = nil
    @answers = {}
  end

  def file=(file)
    last_q = nil
    if File.exist?(file)
      open(file) do |fh|
        fh.each do |line|
          line = line.chomp
          next if line == ''
          if line =~ /^\s+/
            @answers[last_q] = Interviewer.parse(line.strip)
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

  def ask(prompt)
    return @answers[prompt] if @answers[prompt]
    puts prompt
    answer = gets.strip
    persist(prompt, answer)
    answer = Interviewer.parse(answer)
    @answers[prompt] = answer
    return answer
  end

  def self.parse(data)
    case data
    when '-' then BlankZero
    when /^-?\d+$/ then data.to_i
    when /^-?\d*\.\d*$/ then data.to_f
    when /^-?\d+,[\d, -]*$/
      data.split(/,\s*/).map { |x| process_import_data(x) }
    else data
    end
  end


end
