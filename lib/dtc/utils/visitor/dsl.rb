module DTC
  module Utils
    module Visitor
      # Utilities for visiting a DSL block
      #
      # Tolerates chained method calls and
      # recursive blocks, as long as intermediary
      # method calls have no arguments.
      #
      # eg: `some.calls.are.fine(true)`
      #     `some(true).arent`
      #
      # Enters/leaves for methods called with a
      # block. `Visitor#enter`s return is ignored.
      module DSL
        # Utility class to keep track of the
        # running prefix as the DSL is visited
        class RecursiveDSLDelegate
          def initialize visitor, prefix = nil
            @visitor = visitor
            @prefix = prefix
            @pending_prefix = nil
            @called = false
          end
          def prefix sym
            @called = true
            flush
            @pending_prefix = self.class.new(@visitor, with_prefix(sym))
          end
          def flush
            if @pending_prefix
              @pending_prefix.add_unless_called
              @pending_prefix = nil
            end
          end
          def add sym, *args
            @called = true
            @visitor.add(with_prefix(sym), *args)
          end
          def enter sym, *args
            flush
            @called = true
            @visitor.enter(with_prefix(sym), *args)
          end
          def leave
            flush
            @visitor.leave
          end
          protected
          def with_prefix sym
            @prefix ? (sym ? "#{@prefix}.#{sym}".to_sym : @prefix) : sym
          end
          def add_unless_called
            flush
            @visitor.add(@prefix) unless @called
          end
        end
        # Blank slate object providing the `self` context
        # in which DSL blocks are evaluated
        class RecursiveDSLContextBlank
          extend DTC::Utils::Meta
          blank_class :instance_exec, :class
          def initialize delegate, unprefixed = delegate
            @delegate = delegate
            @unprefixed = unprefixed
          end
          def method_missing(meth, *args, &block)
            if block
              @delegate.enter meth, *args
              self.class.new(@unprefixed, @unprefixed).instance_exec(&block)
              @unprefixed.flush
              @delegate.leave
            else
              if args.empty?
                return self.class.new(@delegate.prefix(meth), @unprefixed)
              else
                @delegate.add(meth, *args)
              end
            end
            self
          end
        end
        # Visit the DSL provided in `blk` using `visitor`
        #
        # Context and delegate classes may be subclassed.
        def self.accept visitor, context_klass = RecursiveDSLContextBlank,
            delegate_klass = RecursiveDSLDelegate,
            &blk
          visitor = visitor.new() if visitor.is_a?(Class)
          builder = delegate_klass.new(visitor)
          context_klass.new(builder).instance_exec(&blk)
          builder.flush
          visitor
        end
      end
    end
  end
end