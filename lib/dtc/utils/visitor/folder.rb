module DTC
  module Utils
    module Visitor
      module Folder
        # Forwards visits only when file/folder name
        # match the suite of regexen.
        class FilenameFilteringVisitor < DTC::Utils::Visitor::FilteringForwarder
          # `options` may define:
          #
          # - `:excluded`
          # - `:excluded_files`
          # - `:excluded_directories`
          # - `:included`
          # - `:included_files`
          # - `:included_directories`
          #
          # Each item is then included only if no includes are defined,
          # or it matches one of the includes, and if no exclusions are
          # defined, or it does not match one of the exclusions.
          #
          # Each key of `options` is an array of strings that will be
          # compiled into case-insensitive regexen
          def initialize listener, options = {}
            super listener
            @excluded = compile_regexp(options[:excluded])
            @excluded_files = compile_regexp(options[:excluded_files])
            @excluded_directories = compile_regexp(options[:excluded_directories])
            @included = compile_regexp(options[:included])
            @included_files = compile_regexp(options[:included_files])
            @included_directories = compile_regexp(options[:included_directories])
          end
          protected
          def compile_regexp(rx_list)
            return nil if rx_list.nil? || rx_list.reject { |e| e.length == 0 }.empty?
            Regexp.union(*rx_list.map { |e| /#{e}/i })
          end
          def include?(is_file, name, *args)
            name = File.basename(name) unless is_file
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
        # Visit the path provided using `visitor`,
        # (or a transparent FilenameFilteringVisitor if options
        # include filtering)
        #
        # `options` may include a `:max_depth` key,
        # or any keys used by `FilenameFilteringVisitor`
        def self.accept visitor, path, options = {}
          visitor = visitor.new() if visitor.is_a?(Class)
          options = options.is_a?(Fixnum) ? ({:max_depth => options}) : options.dup
          max_depth = options.delete(:max_depth) { -1 }
          filter = options.empty? ? visitor :
            FilenameFilteringVisitor.new(visitor, options)
          accept_path filter, File.expand_path(path), max_depth
          visitor
        end
        def self.accept_path visitor, path, max_depth = -1
          dir = Dir.new(path)
          return unless visitor.enter path
          dir.each do |f|
            full_path = File.join(path, f)
            next if f == "." || f == ".."
            if File.directory? full_path
              return unless File.readable?(path)
              self.accept_path(visitor, full_path, max_depth - 1) unless max_depth == 0
            else
              visitor.add f, full_path
            end
          end
          visitor.leave
        end
      end
    end
  end
end