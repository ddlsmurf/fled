
module DTC
  module Utils
    module Text
      def self.lines str
        str.split(/\r?\n/).to_a
      end
      # Remove common space-only indent to all non-empty lines
      def self.lines_without_indent lines
        lines = self.lines(lines) unless lines.is_a?(Array)
        lines.shift if lines.first.empty?
        min_spaces = lines.map { |l|
          l == "" ? nil : (l =~ /^( +)/ ? $1.length : 0)
        }.select{ |e| e }.min || 0
        lines.map { |l| (min_spaces == 0 ? l : l[min_spaces..-1]) || "" }
      end

      autoload :HTML, 'dtc/utils/text/html'
      autoload :LineWriter, 'dtc/utils/text/line_writer'
    end
  end
end

