module DTC
  module Utils
    class FileVisitor
      def depth ; @folders.nil? ? 0 : @folders.count ; end
      def current_path *args ; File.join(@folders + args) ; end
      attr_accessor :next_visitor
      def enter dir
        return false unless next_visitor ? next_visitor.enter(dir) : true
        (@folders ||= []) << dir
        true
      end
      def add name, full_path
        next_visitor.add(name, full_path) if next_visitor
      end
      def leave
        next_visitor.leave if next_visitor
        @folders.pop
      end
      def self.browse path, visitor, max_depth = -1
        return unless File.readable?(path)
        dir = Dir.new(path)
        return unless visitor.enter path
        dir.each do |f|
          full_path = File.join(path, f)
          next if f == "." || f == ".."
          if File.directory? full_path
            self.browse(full_path, visitor, max_depth - 1) unless max_depth == 0
          else
            visitor.add f, full_path
          end
        end
        visitor.leave
      end
    end
    class FilteringFileVisitor < FileVisitor
      def initialize listener, options = {}
        @excluded = compile_regexp(options[:excluded])
        @excluded_files = compile_regexp(options[:excluded_files])
        @excluded_directories = compile_regexp(options[:excluded_directories])
        @included = compile_regexp(options[:included])
        @included_files = compile_regexp(options[:included_files])
        @included_directories = compile_regexp(options[:included_directories])
        @recurse = options[:max_depth] || -1
        self.next_visitor = listener
      end
      def enter dir
        return false unless include?(File.basename(dir), false)
        if (result = super) && !descend?(dir)
          leave
          return false
        end
        result
      end
      def add name, full_path
        return false unless include?(name, true)
        super
      end
      protected
      def compile_regexp(rx_list)
        return nil if rx_list.nil? || rx_list.reject { |e| e.length == 0 }.empty?
        Regexp.union(*rx_list.map { |e| /#{e}/i })
      end
      def descend?(name)
        @recurse == -1 || @recurse >= (depth - 1)
      end
      def include?(name, is_file)
        can_include = (@included.nil? || @included.match(name)) &&
          ((is_file && (@included_files.nil? || @included_files.match(name))) ||
           (!is_file && (@included_directories.nil? || @included_directories.match(name))))
        if can_include
          can_include = (@excluded.nil? || !@excluded.match(name)) &&
            ((is_file && (@excluded_files.nil? || !@excluded_files.match(name))) ||
             (!is_file && (@excluded_directories.nil? || !@excluded_directories.match(name))))
        end
        can_include
      end
    end
  end
end