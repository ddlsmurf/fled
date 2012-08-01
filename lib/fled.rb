require 'dtc/utils'
require 'shellwords'

module FlEd
  require 'fled/file_listing'

  VERSION = '0.0.1'

  def self.operation_list_to_bash ops
    ops = ops.map do |op|
      case op.first
      when :mk
        [:mkdir, File.join(op[1])]
      when :moved
        [:mv, File.join(op[1]), File.join(op[2])]
      when :renamed
        [:mv, File.join(op[1]), File.join((op[1].empty? ? [] : op[1][0..-2]) + [op[2]])]
      when :rm
        [op[2][:dir] ? :rmdir : :rm , File.join(op[1])]
      else
        op
      end
    end
    warnings, operations = *ops.partition { |e| e.first == :warn }
    result = []
    unless warnings.empty?
      result = ["# Warning:"]
      warnings.each do |warning|
        result += ["#  - #{warning[1]}: #{File.join(warning[2][:source][:path], warning[3])}"]
      end
      result += ['', 'exit 1 # There are warnings to check first !', '']
    end
    result += operations.map do |op|
      "#{Shellwords.join(op.map(&:to_s))}"
    end
    result
  end
end