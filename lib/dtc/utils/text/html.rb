require 'cgi'

module DTC
  module Utils
    module Text
      module HTML
        class Writer < DTC::Utils::Text::LineWriter
          def enter sym, *args
            attrs = args.last.is_a?(Hash) ? args.pop : {}
            no_indent = attrs && attrs.delete(:no_indent) {
              ! NOINDENT_TAGS.index(sym.to_s.downcase).nil?
            }
            push DTC::Utils::Text::HTML::tag(sym, :open, attrs)
            (@stack ||= []) << sym.to_s.split(".").first
            push_indent("  " + (current_indent || []).join(""))
            if no_indent
              unindented *args
            else
              text *args
            end
            true
          end
          def leave
            pop_indent
            push(DTC::Utils::Text::HTML::tag(@stack.pop.to_sym, :close))
          end
          def add sym, *args
            if self.respond_to?(sym)
              self.__send__(sym, *args)
            else
              attrs = args.last.is_a?(Hash) ? args.pop : {}
              if attrs && attrs.delete(:no_indent) {
                  ! NOINDENT_TAGS.index(sym.to_s.downcase).nil?
                }
                push(DTC::Utils::Text::HTML::tag(sym, :open, attrs))
                unindented *args
                push(DTC::Utils::Text::HTML::tag(sym, :close, attrs))
              else
                push(DTC::Utils::Text::HTML::tag(sym, args, attrs))
              end
            end
          end
          def text *str
            push(*str.flatten.map { |s| CGI::escapeHTML(s) })
          end
          def unindented *str
            push_indent("") { text *str }
          end
        end
        def self.attributes attrs = {}
          unless attrs.nil? || attrs.empty?
            " " + (
              attrs.map do |k, v|
                key = (
                  ATTRIBUTE_ALIASES[k] ||
                  ATTRIBUTE_ALIASES[k.to_s] ||
                  k
                ).to_s
                if v == true
                  CGI::escapeHTML(key)
                elsif !v
                  nil
                else
                  "#{CGI::escapeHTML(key)}='#{CGI::escapeHTML(v.is_a?(Array) ? v.join(" ") : v.to_s)}'"
                end
              end).select {|e| e} .join(" ")
          else
            ""
          end
        end
        ATTRIBUTE_ALIASES = ({})
        SHORTFORM_TAGS = %w[area base basefont br col frame hr img input link meta param]
        NOINDENT_TAGS = %w[pre textarea]
        def self.tag sym, content = :open_close, attrs = {}
          tag = sym.to_s.split(".")
          nature = :open_close
          content = content.join("") if content.is_a?(Array)
          if content.is_a?(Symbol)
            nature = content unless content == :full
          elsif !content.nil? && content.strip != ""
            nature = :full
          else
            nature = SHORTFORM_TAGS.index(tag.first.downcase) ? :short : :open_close
          end
          tag_header = tag_name = tag.first.to_s
          unless (nature = nature.to_sym) == :close
            if tag.count > 1
              attrs ||= {}
              classes = attrs[:class] || []
              classes = classes.split(/\s+/) if classes.is_a?(String)
              classes += tag.drop(1).to_a
              attrs[:class] = classes.uniq
            end
            tag_header += attributes(attrs) unless nature == :close
          end
          natures = ({:open => %w[< >], :close => ['</', '>'], :short => ['<', ' />'], :open_close => ['<', "></#{tag_name}>"]})
          if nature == :full
            natures[:open].join(tag_header) + content + natures[:close].join(tag_name)
          else
            raise RuntimeError, "Unknown tag nature #{nature.inspect}, should be one of #{natures.keys.to_a.inspect}" unless natures[nature]
            natures[nature].join(tag_header)
          end
        end
      end
    end
  end
end