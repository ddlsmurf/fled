require 'dtc/utils'
require 'shellwords'

module FlEd
  require 'fled/file_listing'
  require 'fled/file_listing_builder'

  VERSION = '0.0.2'

  # Convert file listing operation list
  # to bash-script friendly script
  def self.operation_list_to_bash ops
    ops = ops.map do |op|
      case op.first
      when :mk
        [:mkdir, File.join(op[1])]
      when :moved
        [:mv, File.join(op[1]), File.join(op[2])]
      when :renamed
        [:mv, File.join(op[1]), File.join((op[1].empty? ? [] : op[1][0..-2]) + [op[2]])]
      when :rm, :rmdir
        [op.first , File.join(op[1])]
      else
        op
      end
    end
    warnings, operations = *ops.partition { |e| e.first == :warn }
    errors, operations = *operations.partition { |e| e.first == :fail }
    result = []
    unless errors.empty?
      result += ["# Error:"]
      errors.each do |error|
        line = error[2][:line_number]
        result += ["#  - line #{line}: #{error[1]}"]
      end
      result += ['', 'exit 1 # There are errors to check first !', '']
    end
    unless warnings.empty?
      result += ["# Warning:"]
      warnings.each do |warning|
        line = warning[2][:line_number]
        result += ["#  - line #{line}: #{warning[1]}: #{File.join(warning[3])}"]
      end
      result += ['', 'exit 1 # There are warnings to check first !', '']
    end
    result += operations.map do |op|
      "#{Shellwords.join(op.map(&:to_s))}"
    end
    result
  end
end