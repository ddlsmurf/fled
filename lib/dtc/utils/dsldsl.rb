module DTC
  module Utils
    module DSLDSL
      class DSLVisitor
        # very approximate visitor =)
        def enter key, *args ;  end
        def leave ; end
        def add key, *args ; end
        def visit_dsl &blk
          builder = self.class.delegate_klass.new(self)
          self.class.context_klass.new(builder).__instance_exec(&blk)
          builder.flush
        end
        protected
        def self.delegate_klass ; StaticTreeDSLDelegate ; end
        def self.context_klass ; StaticTreeDSLContextBlank ; end
      end

      class DSLArrayWriter < DSLVisitor
        attr_reader :stack
        def initialize
          @stack = [[]]
        end
        def enter sym, *args
          @stack.push [[sym, *args]]
        end
        def leave
          @stack.pop
        end
        def add sym, *args
          @stack.last << [sym, *args]
        end
        def each &blk
          return enum_for(:each) unless block_given?
          each_call_of @stack.first, &blk
        end
        protected
        def each_call_of parent, &block
          parent.each do |item|
            if item.first.is_a?(Symbol)
              yield item
            else
              each_call_of item, &block
            end
          end
        end
      end

      class DSLHashWriter < DSLVisitor
        def initialize target
          @stack = [target]
        end
        def enter key, *args
          container = add_container(key, *args)
          @stack.push(container) if container
          container
        end
        def leave
          @stack.pop
        end
        def add key, *args
          add_key key, args
        end
        def self.write_static_tree_dsl target = {}, &blk
          visitor = self.new(result = target)
          visitor.visit_dsl(&blk)
          result
        end
        def add_container key, *args
          container = {}
          container[:options] = args unless args.empty?
          add_key key, container
        end
        def add_key key, val
          container = @stack.last
          key = key.to_s
          raise RuntimeError, "Key #{key.inspect} already defined" if container[key]
          container[key] = val
          val
        end
      end

      class StaticTreeDSLDelegate
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

      class StaticTreeDSLContextBlank
        alias_method :__instance_exec, :instance_exec
        alias_method :__class, :class
        instance_methods.each { |meth| undef_method(meth) unless meth =~ /\A__/ || meth == :object_id }
        def initialize delegate, unprefixed = delegate
          @delegate = delegate
          @unprefixed = unprefixed
        end
        def method_missing(meth, *args, &block)
          if block
            @delegate.enter meth, *args
            __class.new(@unprefixed, @unprefixed).__instance_exec(&block)
            @unprefixed.flush
            @delegate.leave
          else
            if args.empty?
              return __class.new(@delegate.prefix(meth), @unprefixed)
            else
              @delegate.add(meth, *args)
            end
          end
          self
        end
      end

      if __FILE__ == $0

        class DebugStaticTreeDSLDelegate < StaticTreeDSLDelegate
          def prefix sym
            p [:prefix, sym, @prefix]
            super
          end
          def flush
            p [:flush, @prefix] if @pending_prefix
            super
          end
          def add sym, *args
            p [:add, sym, @prefix]
            super
          end
          def enter sym, *args
            p [:enter, sym, @prefix]
            super
          end
          def leave
            p [:leave, @prefix]
            super
          end
          def add_unless_called
            p [:flush_self, @prefix] unless @called
            super
          end
        end

        class DebugDSLHashWriter < DSLHashWriter
          def enter sym, *args
            p [:wenter, sym]
            super
          end
          def leave
            p [:wleave]
            super
          end
          def add sym, *args
            p [:wadd, sym, args]
            super
          end
          def self.delegate_klass ; DebugStaticTreeDSLDelegate ; end
        end

        module Examples
          module Simple
            result = DSLHashWriter.write_static_tree_dsl do
              fichier "value"
              fichier2.txt "one", "two"
            end
            result # => {"fichier"=>["value"], "fichier2.txt"=>["one", "two"]}

            result = DSLHashWriter.write_static_tree_dsl do
              dossier {
                sous.dossier "valeur" do
                  file.txt
                end
              }
            end
            result # => {"dossier"=>{"sous.dossier"=>{:options=>["valeur"], "file.txt"=>[]}}}

            result = DSLHashWriter.write_static_tree_dsl do
              %w[hdpi mdpi ldpi].each do |resolution|
                image.__send__(resolution.to_sym).png
              end
            end
            result # => {"image.ldpi.png"=>[], "image.hdpi.png"=>[], "image.mdpi.png"=>[]}

            result = DSLHashWriter.write_static_tree_dsl do
              user {
                name :string
                email :string
                address(:json) {
                  line :string
                  country
                }
              }
            end
            result # => {"user"=>{"address"=>{"country"=>[], "line"=>[:string], :options=>[:json]}, "name"=>[:string], "email"=>[:string]}}

            result = DSLHashWriter.write_static_tree_dsl do
              def base_file
                yes.this.is.base
              end
              base_file.txt
              base_file.png
            end
            result # => {"yes.this.is.base.png"=>[], "yes.this.is.base.txt"=>[]}
          end
          module CustomBuilder
            class EscapableStaticTreeDSLContextBlank < StaticTreeDSLContextBlank
              def method_missing(meth, *args, &block)
                meth = args.shift if meth == :raw
                super(meth, *args, &block)
              end
            end
            class EscapableDSLHashWriter < DSLHashWriter
              def self.context_klass ; EscapableStaticTreeDSLContextBlank ; end
            end
            result = EscapableDSLHashWriter.write_static_tree_dsl do
              3.times { |i| raw(i).png }
              image.raw("%!") { file }
            end
            result # => {"0.png"=>[], "1.png"=>[], "image.%!"=>{"file"=>[]}, "2.png"=>[]}
          end
        end
      end
    end
  end
end
