if Kernel.respond_to?(:require_relative)
  require_relative "helper"
else
  require File.join(File.dirname(__FILE__), 'helper')
end

class MarkdownDumbLineWriter < DTC::Utils::Text::LineWriter
  def nl ; push_raw "" ; end
  def text *str
    push DTC::Utils::Text.lines_without_indent(split_lines(*str))
  end
  def para *str
    enter_mode nil
    text *str
  end
  def title str, depth = 2, *args
    enter_mode :title
    push_raw "#{"#" * depth} #{str}"
    para *args unless args.empty?
  end
  # h1-5
  5.times do |i|
    define_method "h#{i + 1}".to_sym do |str, *a|
      title str, i + 1, *a
    end
  end
  def html *str ;
    enter_mode :html
    push_raw *str
  end
  def strong str ; para "**#{str}**" ; end
  def em str ; para "*#{str}*" ; end
  ({
    :li => "- ",
    :pre => "    ",
    :quote => "> ",
  }).each_pair do |method, indentation|
    define_method method do |*str, &blk|
      enter_mode method
      push_indent(indentation) {
        push_unindented_and_yield str, &blk
      }
    end
  end
  protected
  def enter_mode mode
    nl if lines.last != "" && @mode != mode
    @mode = mode
  end
  def split_lines *lines
    result = lines.flatten.map { |l| DTC::Utils::Text::lines(l) }.flatten
    result.shift while result.first == ""
    result.pop while (result.last || "").strip == ""
    result
  end
  def push_unindented_and_yield lines
    push(DTC::Utils::Text.lines_without_indent(split_lines(lines))) if lines
    yield if block_given?
  end
end

class MarkdownDumbLineWriter
  include DTC::Utils::Visitor::AcceptAsFlatMethodCalls
end

class MarkdownAndHTMLVisitor < DTC::Utils::Visitor::Switcher
  def initialize
    @writer = MarkdownDumbLineWriter.new
    super @writer
  end
  def to_s
    @writer.to_s
  end
  protected
  def visitor_for_subtree sym, *args
    if @visitor_stack.count == 1 && sym == :html
      DTC::Utils::Text::HTML::Writer.new
    else
      nil
    end
  end
  def visitor_left_subtree visitor, *args
    add :html, visitor.to_s
  end
end

def readme &blk
  puts DTC::Utils::Visitor::DSL::accept(MarkdownAndHTMLVisitor, &blk).to_s
end

readme do
  def show_example listing, example, operations
    html {
      table {
        tr {
          th { em "Original listing" }
          th { em "Edited listing" }
        }
        tr {
          td { pre listing }
          td { pre(DTC::Utils::Text.lines_without_indent example) }
        }
        tr {
          th(:colspan => 2) { em "Generates the script:" }
        }
        tr {
          td(:colspan => 2) {
            if operations.empty?
              em "No operation"
            else
              ul {
                operations.each { |op| li { code op } }
              }
            end
          }
        }
      }
    }
  end
  def run_example fs, example
    ops = fs.commands_if_edited_as(example)
    show_example fs.new_listing.to_s, example, ops
  end

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
      para t
      pre c
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

  pre fs.new_listing.to_s

  para <<-MD
    Each line of the listing is in the format `[indentation] name: uid`

    - The *indentation* must consist of only spaces, and is used to indicate the parent folder
    - The *name* must not use colons (`:`). If it is cleared, it is assumed the file/folder is to be deleted
      The *name* has a `/` appended if it is a directory.
    - The *uid* is used by FlEd to recognise the original of the edited line. Do not assume a *uid* does not
      change between runs. It is valid only for the current run. Spaces before the *uid* are only cosmetic.
  MD

  h2 "Operations"

  h3 "Creating a new folder", 'Add a new line (therefore with no uid):'
  run_example fs, <<-EXAMPLE
    folder/         :0
      new_folder
      folder_two/   :2
  EXAMPLE

  h3 "Moving"
  para 'Change the indentation and/or line order to change the parent of a file or folder:'
  run_example fs, <<-EXAMPLE
    folder/          :0
      folder_two/    :2
        file_one       :1
        file_three   :3
  EXAMPLE
  em 'Moving an item below itself or its children is not recommended, as the listing may not be exhaustive'

  h3 "Renaming"
  para 'Edit the name while preserving the uid to rename the item'
  run_example fs, <<-EXAMPLE
    folder_renamed/  :0
      file_one       :1
      folder_two/    :2
        file_changed :3
  EXAMPLE

  h3 "Deleting", 'Clear a name but leave the uid to delete that item'
  run_example fs, <<-EXAMPLE
    folder_renamed/  :0
      :1
      :2
      :3
  EXAMPLE

  h3 "No-op"
  para 'If a line (and all child-lines) is removed from the listing, it will have no operation.'
  run_example fs, <<-EXAMPLE
    folder/          :0
  EXAMPLE
  para '*Note that removing a folder without removing its children will move its children:*'

  run_example fs, <<-EXAMPLE
    folder/          :0
      file_one       :1
      file_three   :3
  EXAMPLE

  nl
  para "If an indent is forgotten:"

  run_example fs, <<-EXAMPLE
    folder/          :0
      file_one       :1
        file_three   :3
  EXAMPLE

  h3 "All together"
  run_example fs, <<-EXAMPLE
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
  pre fs.new_listing.to_s
  para "When applying"
  run_example fs, <<-EXAMPLE
    folder/        :0
      file_two   :1
      file_one   :2
  EXAMPLE
  para '*Swapping file names may not work in cases where the generated intermediary file exists but was not included in the listing*'

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
  pre fs.new_listing.to_s
  para "When applying"
  run_example fs, <<-EXAMPLE
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
    'v0.0.3' => [
      'New: Interactive mode with `-u`',
      'New: Error and warning reporting with line numbers',
      'New: Default configuration file at `~/.fled.yaml`',
      'New: Editor and diff tool are configurable from configuration files',
      'Meta: Refactoring of code',
    ],
    'v0.0.4' => [
      'New: Sort file listing (if gem naturalsort is installed, it is used too)',
      'Fix: Non interactive run mode had a bug',
    ],
  }).sort { |a, b| b[0] <=> a[0] }.each do |version, changes|
    em "Version #{version}"
    li *changes
  end

  h2 "Disclaimer", <<-MD
      Warning: This is a very dangerous tool. The author recommends you do not
        use it. The author cannot be held responsible in any case.
  MD

  h2 "Contributors"
  li "[Eric Doughty-Papassideris](http://github.com/ddlsmurf)"

  h2 "Licence", "[GPLv3](http://www.gnu.org/licenses/gpl-3.0.html)"

end
