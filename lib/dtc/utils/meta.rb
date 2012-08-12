
module DTC
  module Utils
    module Meta
      # Undefines all methods except those
      # provided as arguments, or if empty,
      # `class`.
      #
      # To undefine even class, specify as
      # argument: `:no_really_i_dont_even_want_class`
      def blank_class *exceptions
        exceptions = exceptions.flatten.map(&:to_sym)
        exceptions = [:class] if exceptions.empty? && exceptions != [:no_really_i_dont_even_want_class]
        instance_methods.each { |meth| undef_method(meth) unless meth =~ /\A__/ || meth == :object_id || exceptions.index(meth.to_sym) }
      end
      # Replaces provided instance methods,
      # specified by name or regexp, with
      # a call that provides the original
      # method as an argument.
      #
      # To define a pass-through method, use:
      #     class Test
      #       extend DTC::Utils::Meta
      #       def test
      #       end
      #       advise :test do |original, *args, &blk|
      #         original.call(*args, &blk)
      #       end
      #     end
      def advise *method_names, &block
        method_names = method_names.map { |e| e.is_a?(Regexp) ? instance_methods.select { |m| m =~ e } : e }
        method_names.flatten.each { |e| advise_method(e.to_sym, &block) }
      end
      protected
      def advise_method method_name, &block
        method_name = method_name.to_sym
        method = self.instance_method(method_name)
        define_method(method_name) do |*a, &b|
          original = lambda { |*args, &sub|
            method.bind(self).call(*args, &sub)
          }
          block.call(original, *a, &b)
        end
      end
    end
  end
end