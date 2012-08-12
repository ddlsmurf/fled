module DTC
  module Utils
    # Utilities for objects that repond to:
    #
    # - `enter(*arguments)`: return true to enter branch
    # - `leave()`
    # - `add(*arguments)
    module Visitor
      autoload :DSL, 'dtc/utils/visitor/dsl'
      autoload :Folder, 'dtc/utils/visitor/folder'

      # Forward visitor events to current
      # value of `next_visitor`. Defaults
      # to returning `true` for all `enter()`
      class Forwarder
        attr_accessor :next_visitor
        def initialize next_visitor = nil
          self.next_visitor = next_visitor if next_visitor
        end
        def enter *args
          next_visitor ? next_visitor.enter(*args) : true
        end
        def add *args
          next_visitor.add(*args) if next_visitor
        end
        def leave
          next_visitor.leave if next_visitor
        end
      end

      # Base class for visitors that redirect their calls
      # to other visitors for sub-branches.
      #
      # Override `visitor_for_subtree` and return a new visitor
      # to begin receiving calls *below* current symbol.
      #
      # When the branch is visited and after the new visitor
      # is popped, `visitor_left_subtree` is called with original
      # arguments as given to `enter`.
      class Switcher < Forwarder
        def initialize receiver
          @visitor_full_stack = [receiver]
          @visitor_stack = [[receiver]]
          super receiver
        end
        def enter *args
          sub_visitor = visitor_for_subtree(*args)
          @visitor_full_stack.push(sub_visitor)
          if sub_visitor
            @visitor_stack.push([sub_visitor, *args])
            self.next_visitor = sub_visitor
          else
            super
          end
        end
        def leave
          visitor = @visitor_full_stack.pop
          if visitor
            previous_visitor = @visitor_stack.pop
            self.next_visitor = (@visitor_stack.last || []).first
            visitor_left_subtree *previous_visitor
          else
            super
          end
        end
        protected
        def visitor_for_subtree *args
          nil
        end
        def visitor_left_subtree visitor, *args
        end
      end

      # Printing forwarding visitor
      #
      # The constructor accepts a block to replace the
      # default printing mecanism.
      class Printer < Forwarder
        def initialize next_visitor = nil, &printer # :yields: depth, method, *args
          @printer = printer || lambda { |depth, method, *args|
            puts(
              ("  " * depth) +
              method.inspect +
              (args.empty? ? "" : " " + args.inspect)
            )
          }
          @depth = 0
          super next_visitor
        end
        def enter *args
          print :enter, *args
          @depth += 1
          super
        end
        def leave
          @depth -= 1
          super
        end
        def add *args
          print :add, *args
          super
        end
        protected
        def print method, *args
          @printer.call(@depth, method, *args)
        end
      end

      # Base class for visitors that create a data
      # structure based on calls.
      #
      # Obtain result of visit with `root`
      #
      # Default behaviour is to build an
      # array based structure. Override `new_inner`
      # to create and return new inner nodes,
      # and `new_outer` to create and return outer
      # nodes.
      #
      # Example:
      #     DTC::Utils::Visitor::DSL::accept(DTC::Utils::Visitor::Builder) {
      #       container(:arg1) { child_item(:arg2) }
      #       root_child_item
      #     }.root
      #    
      #     =>
      #    
      #     [[:inner, [:container, :arg1], [:outer, [:child_item, :arg2]]],
      #      [:outer, [:root_child_item]]]
      class Builder
        def initialize root = []
          @stack = [root]
        end
        def root
          @stack.first
        end
        def enter *args
          container = new_inner(*args)
          @stack.push(container) if container
          container
        end
        def leave
          @stack.pop
        end
        def add *args
          new_outer *args
        end
        protected
        # Last value provided by `new_inner`, also
        # known as "current parent"
        def current_inner_node
          @stack.last
        end
        def new_inner *args
          container = [:inner, args]
          current_inner_node << container
          container
        end
        def new_outer *args
          current_inner_node << [:outer, args]
        end
      end

      # Adds a replay ability to the builder visitor.
      class Recorder < Builder
        # Replay all calls made on self to `visitor`
        def accept visitor
          visitor = visitor.new if visitor.is_a?(Class)
          accept_inner visitor, root
        end
        protected
        def accept_inner visitor, inner
          inner.each do |node|
            case node.first
            when :outer
              visitor.add *node.last
            when :inner
              if visitor.enter(*node[1])
                accept_inner(visitor, node.drop(2))
                visitor.leave
              else
                puts"NO"
              end
            else
              raise RuntimeError, "Unknown node: #{node.inspect}"
            end
          end
          visitor
        end
      end

      # Subclasses the `Builder` to create
      # hash based hierarchies, using the first
      # argument as the key in the parent hash
      #
      # Does not tolerate duplicate keys by default.
      # Override `key_collision` to change this.
      #
      # Example:
      #
      #     DTC::Utils::Visitor::DSL::accept(DTC::Utils::Visitor::HashBuilder) {
      #       container(:arg1) { child_item(:arg2) }
      #       root_child_item
      #     }.root
      #    
      #     =>
      #    
      #     {:container=>{nil=>[:arg1], :child_item=>[:arg2]}, :root_child_item=>[]}
      class HashBuilder < Builder
        def initialize root = {}
          super root
        end
        protected
        def key_collision key, new_args, previous_args
          raise RuntimeError, "Key #{key.inspect} already defined" if container[key]
        end
        def add_child key, value
          container = current_inner_node
          if (previous = container[key])
            value = key_collision(key, value, previous)
          end
          container[key] = value
          value
        end
        def new_inner key, *args
          container = {}
          container[nil] = args unless args.empty?
          add_child key, container
        end
        def new_outer key, *args
          add_child key, args
          args
        end
      end

      # Base class for forwarding visitors
      # that forward events only for items
      # on which a call to `include?(is_leaf, *args)`
      # returns true.
      #
      # You can include, but not descend,
      # a node by overriding `descend?(*args)` too.
      class FilteringForwarder < Forwarder
        def enter *args
          return false unless include?(false, *args)
          if (result = super) && !descend?(*args)
            leave
            return false
          end
          result
        end
        def add *args
          return false unless include?(true, *args)
          super
        end
        protected
        def descend?(*args) ; true ; end
        def include?(is_leaf, *args) ; true ; end
      end

      # Include this module in a class that
      # responds to a flat tree visit, so only `add`
      # methods, where the first argument is expected
      # to be a symbol the class responds to
      module AcceptAsFlatMethodCalls
        def enter *args ; raise RuntimeError, "Blocks are not supported for #{self.class.name} (got on #{args.inspect})" ; end
        def leave ; end
        def add sym, *args ; self.__send__(sym, *args) ; end
      end
    end
  end
end