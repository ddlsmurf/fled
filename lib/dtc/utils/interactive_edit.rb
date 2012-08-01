require 'yaml'
require 'tempfile'
require 'shellwords'
begin
  require 'platform'
rescue LoadError
end

module DTC::Utils
  # Copied from gem utility_belt (and modified, so get your own copy http://utilitybelt.rubyforge.org)
  # Giles Bowkett, Greg Brown, and several audience members from Giles' Ruby East presentation.
  class InteractiveEditor
    DEBIAN_SENSIBLE_EDITOR = "/usr/bin/sensible-editor"
    MACOSX_OPEN_CMD        = ["open", "--wait-apps", "-e"]
    WIN_START_CMD          = ["start", "-w"]
    XDG_OPEN               = "/usr/bin/xdg-open"
    def self.sensible_editor
      return Shellwords::split(ENV["VISUAL"]) if ENV["VISUAL"]
      return Shellwords::split(ENV["EDITOR"]) if ENV["EDITOR"]
      if defined?(Platform)
        return WIN_START_CMD if Platform::IMPL == :mswin
        return MACOSX_OPEN_CMD if Platform::IMPL == :macosx
        if Platform::IMPL == :linux
          if File.executable?(XDG_OPEN)
            return XDG_OPEN
          end
          if File.executable?(DEBIAN_SENSIBLE_EDITOR)
            return DEBIAN_SENSIBLE_EDITOR
          end
        end
      end
      raise "Could not determine what editor to use.  Please specify (or use platform gem)."
    end
    attr_accessor :editor
    def initialize(editor = InteractiveEditor.sensible_editor, extension = ".yaml")
      @editor = @editor == "mate" ? ["mate", "-w"] : editor
      @extension = extension
      @file = nil
    end
    def filename
      @file ? @file.path : nil
    end
    def edit_file_interactively(filename)
      Exec.sys(@editor, filename)
    end
    def edit_interactively(content)
      unless @file
        @file = Tempfile.new(["#{File.basename(__FILE__, File.extname(__FILE__))}-edit", @extension])
        @file << content
        @file.close
      end
      edit_file_interactively(@file.path)
      IO::read(@file.path)
      rescue Exception => error
        @file.unlink
        @file = nil
        puts error
    end
    def self.edit_file(filename, editor = InteractiveEditor.sensible_editor)
      editor = InteractiveEditor.new editor
      editor.edit_file_interactively(filename)
      rescue Exception => error
        puts "# !!!" + error.inspect
        raise
        return nil
    end
    def self.edit(content, extension = ".yaml", editor = InteractiveEditor.sensible_editor)
      InteractiveEditor.new(editor, extension).edit_interactively(content)
    end
    def self.edit_in_yaml(object, editor = InteractiveEditor.sensible_editor)
      input = "# Just empty and save this document to abort !\n" + object.to_yaml
      editor = InteractiveEditor.new editor
      res = editor.edit_interactively(input)
      YAML::load(res)
      rescue Exception => error
        puts "# !!!" + error.inspect
        raise
        return nil
    end
  end
end