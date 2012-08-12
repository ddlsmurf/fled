module DTC
  module Utils
    module Text
      # Helper class for writting lines of text,
      # with some indentation processing.
      #
      # Blocks of text can be indented and/or
      # captured.
      #
      # Output is written to an array in `lines`
      # by `push_raw`. Other methods use `split_lines`
      # and/or `indent_lines` to preprocess input.
      #
      # Get the result by 
      class LineWriter
        def lines ; @lines || [] end
        def to_s sep = "\n"
          lines.join(sep)
        end
        def begin_capture
          (@lines_stack ||= []) << @lines
          @lines = []
          if block_given?
            yield
            end_capture
          end
        end
        def end_capture
          result = @lines
          @lines = @lines_stack.pop
          result
        end
        def push_raw *raw_lines
          @lines = lines + raw_lines.flatten
        end
        def push_indent *indent, &blk
          (@indents ||= []) << indent
          if block_given?
            yield
            pop_indent
          end
        end
        def pop_indent
          @indents.pop
        end
        def current_indent
          @indents && @indents.last
        end
        def push *lines
          if (indent = current_indent)
            push_raw(indent_lines(split_lines(*lines), indent))
          else
            push_raw *lines
          end
        end
        alias_method :<<, :push
        protected
        def split_lines *lines
          lines.flatten
        end
        def indent_lines lines, indent
          lines = split_lines(lines)
          lines.map { |line|
            indent.join("") + line
          }
        end
      end
    end
  end
end