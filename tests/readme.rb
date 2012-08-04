if Kernel.respond_to?(:require_relative)
  require_relative "helper"
else
  require File.join(File.dirname(__FILE__), 'helper')
end

class MarkdownDumbWriter
  def initialize
    @result = []
  end
  def ensure_clear exception = nil
    unless @result.last == ""
      @result << ""
    else
      if exception && @result.length > 1 &&
         (@result[-2] || "")[0..exception.length - 1] == exception
        @result.pop
      end
    end
  end
  def << str ; @result += str.is_a?(Array) ? str : [str] ; end
  def nl ; @result += [""] ; end
  def title str, depth = 2, *args
    ensure_clear "#"
    self << "#{"#" * depth} #{str}"
    nl
    args.each { |a| text a }
  end
  def h1 str, *a ; title str, 1, *a ; end
  def h2 str, *a ; title str, 2, *a ; end
  def h3 str, *a ; title str, 3, *a ; end
  def code str, indent = "    "
    ensure_clear
    self << reindent(str, indent)
    nl
  end
  def reindent str, indent = ""
    lines = str.split(/\r?\n/).map
    lines.shift if lines.first.empty?
    min_spaces = lines.map { |l| l =~ /^( +)/ ? $1.length : nil }.select{ |e| e }.min || 0
    lines.map { |l| indent + ((min_spaces == 0 ? l : l[min_spaces..-1]) || "") }
  end
  def text str ; self << reindent(str, "") ; end
  def em str ; text "*#{str}*" ; end
  def li str ;
    ensure_clear "-"
    self << reindent(str, "- ")
    nl
  end
  def show_example fs, example
    code example
    ops = fs.commands_if_edited_as(example)
    text "Generates:"
    if ops.empty?
      em "No operation"
    else
      code ops.join("\n")
    end
  end
  def result ; @result.join("\n") ; end
end

class ExampleDSLWriter < DTC::Utils::DSLDSL::DSLArrayWriter
  def self.run &blk
    visitor = self.new()
    visitor.visit_dsl(&blk)
    writer = MarkdownDumbWriter.new
    visitor.each do |method, *args|
      writer.__send__(method, *args)
    end
    writer.result
  end
end

readme = ExampleDSLWriter.run do
  h1 "FlEd", '`fled` lets you organise your files and folders in your favourite editor'

  h2 "Introduction", <<-MD
  `fled` enumerates a folder and its files, and generates a text listing.
  You can then edit that listing in your favourite editor, and save changes.
  `fled` then reloads those changes, and prints a shell script that would move
  your files and folders around as-per your edits.
  
  **You should review that shell script very carefully before running it.**
  
  MD

  h3 "Install", <<-MD
    You can install using `gem install fled`.
  MD

  h3 "Philosophy", <<-MD
    `fled` only generates text, it does not perform any operation directly.

    The design optimises for making the edits very simple. This means that very small
    edits can have large consequences, which makes this a **very dangerous** tool.
    But so is `rm` and the rest of the shell anyway...
  MD

  h3 "Caveats", <<-MD
    `fled` is only aware of files it scanned. It will not warn for overwrites,
    nor use temporary files in those cases, etc.

    `fled`'s editing model is rather complex and fuzzy. While there are some test
    cases defined, any help is much appreciated.

    You should be scared when using `fled`.
  MD

  h3 "Test status", "[![Build Status](https://secure.travis-ci.org/ddlsmurf/fled.png?branch=master&this_url_now_ends_with=.png)](http://travis-ci.org/ddlsmurf/fled)"

  h3 "Examples"
  [
    ["Print help text and option list", "fled --help"],
    ["Edit current folder", "fled"],
    ["Edit all files directly in `path` folder", "fled -a path -d 0"],
    ["Save default options", "fled --options > fled.config.yaml"],
    ["Edit current folder using options", "fled --load fled.config.yaml"],
    ["Add options to a command (`mkdir`, `mv`, `rm` or `rmdir`)", "fled | sed 's/^mv/mv -i/'"],
  ].each do |t, c|
      text t
      code c
  end

  h2 "Listing Format"

  fs = TestFS.new do
    folder(0) {
      file_one(1)
      folder_two(2) {
        file_three(3)
      }
    }
  end

  code fs.new_listing.to_s

  text <<-MD
    Each line of the listing is in the format *`[indentation]`* *`[name]`* `:`*`[uid]`*

    - The *indentation* must consist of only spaces, and is used to indicate the parent folder
    - The *name* must not use colons (`:`). If it is cleared, it is assumed the file/folder is to be deleted
    - The *uid* is used by FlEd to recognise the original of the edited line. Do not assume a *uid* does not
      change between runs. It is valid only once.
  MD

  h2 "Operations"

  h3 "Creating a new folder", 'Add a new line (therefore with no uid):'
  show_example fs, <<-EXAMPLE
    folder/         :0
      new_folder
      folder_two/   :2
  EXAMPLE

  h3 "Moving"
  text 'Change the indentation and/or line order to change the parent of a file or folder:'
  show_example fs, <<-EXAMPLE
    folder/          :0
      folder_two/    :2
        file_one       :1
        file_three   :3
  EXAMPLE
  em 'Moving an item below itself or its children is not recommended, as the listing may not be exhaustive'

  h3 "Renaming"
  text 'Edit the name while preserving the uid to rename the item'
  show_example fs, <<-EXAMPLE
    folder_renamed/  :0
      file_one       :1
      folder_two/    :2
        file_changed :3
  EXAMPLE
  text '*Swapping file names may not work in cases where the generated intermediary file exists but was not included in the listing*'

  h3 "Deleting", 'Clear a name but leave the uid to delete that item'
  show_example fs, <<-EXAMPLE
    folder_renamed/  :0
      :1
      :2
      :3
  EXAMPLE

  h3 "No-op"
  text 'If a line (and all child-lines) is removed from the listing, it will have no operation.'
  show_example fs, <<-EXAMPLE
    folder/          :0
  EXAMPLE
  nl
  nl
  text '*Note that removing a folder without removing its children will move its children:*'

  show_example fs, <<-EXAMPLE
    folder/          :0
      file_one       :1
      file_three   :3
  EXAMPLE

  nl
  text "If an indent is forgotten:"

  show_example fs, <<-EXAMPLE
    folder/          :0
      file_one       :1
        file_three   :3
  EXAMPLE

  h3 "All together"
  show_example fs, <<-EXAMPLE
    folder_new/          :0
      new_folder/
        first    :1
        second   :3
      :2
  EXAMPLE

  h2 "Edge cases", "These sort-of work, but are still rather experimental"

  h3 "Swapping files"

  fs = TestFS.new do
    folder(0) {
      file_one(1)
      file_two(2)
    }
  end
  code fs.new_listing.to_s
  text "When applying"
  show_example fs, <<-EXAMPLE
    folder/        :0
      file_two   :1
      file_one   :2
  EXAMPLE

  h3 "Tree swapping"
  fs = TestFS.new do
    folder(0) {
      sub_folder(1) {
        sub_sub_folder(2) {
          file.txt(3)
        }
      }
    }
  end
  code fs.new_listing.to_s
  text "When applying"
  show_example fs, <<-EXAMPLE
    sub_sub_folder/  :2
      sub_folder/        :1
        folder/              :0
          file.txt       :3
  EXAMPLE

  h2 "Changelog"
  ({
    'v0.0.1' => ['First version'],
    'v0.0.2' => [
      'Fix: Unreadable directories now ignored',
      'Fix: Version display and DRYed',
      'Fix: Moving files under files now moves up to parent folder of destination',
      'Meta: Travis-CI integration',
    ],
  }).sort { |a, b| b[0] <=> a[0] }.each do |version, changes|
    em "Version #{version}"
    changes.each { |change| li change }
  end

  h2 "Disclaimer", <<-MD
      Warning: This is a very dangerous tool. The author recommends you do not
        use it. The author cannot be held responsible in any case.
  MD

  h2 "Contributors"
  li "[Eric Doughty-Papassideris](http://github.com/ddlsmurf)"

  h2 "Licence", "[GPLv3](http://www.gnu.org/licenses/gpl-3.0.html)"

end
puts readme