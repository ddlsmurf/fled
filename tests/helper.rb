#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__),'../lib')
require 'fled'

class PrintingFileVisitor < DTC::Utils::FileVisitor
  def enter_folder dir
    depth = self.depth
    puts ("  " * depth) + (depth > 0 ? File.basename(dir) : dir)
    super
  end
  def visit_file name, full_path
    puts ("  " * depth) + name
    super
  end
end

class TestListingBuilder < FlEd::ListingBuilder
  def next_uid
    @uid
  end
  def enter_folder dir, uid = nil
    @uid = uid
    super dir
  end
  def visit_file name, uid
    @uid = uid
    super name, current_path(name)
  end
end

class TestFS
  def initialize &block
    @root = DTC::Utils::DSLDSL::DSLHashWriter.write_static_tree_dsl(&block)
  end
  def receive visitor, root = @root
    root.each_pair do |name, val|
      next if name == :options
      if val.is_a?(Array)
        visitor.visit_file name, val[0]
      elsif val.is_a?(Hash)
        if visitor.enter_folder(name, val[:options][0])
          receive(visitor, val)
          visitor.leave_folder
        end
      else
        raise RuntimeError, "Unknown value #{val.inspect}"
      end
    end
  end
  def new_builder
    builder = TestListingBuilder.new
    builder.enter_folder("$")
    receive builder
    builder.leave_folder
    builder
  end
  def new_listing
    new_builder.listing
  end
  def operation_list_if_edited_as edited_text
    listing = new_listing
    parsed = FlEd::FileListing.parse(edited_text)
    parsed.operations_from!(listing)
  end
  def operations_if_edited_as edited_text
    operation_list_if_edited_as(edited_text).map do |op|
      case op.first
      when :mk
        [:mkdir, File.join(op[1])]
      when :moved
        [:mv, File.join(op[1]), File.join(op[2])]
      when :renamed
        [:mv, File.join(op[1]), File.join((op[1].empty? ? [] : op[1][0..-2]) + [op[2]])]
      when :rm
        [op[2][:dir] ? :rmdir : :rm , File.join(op[1])]
      else
        op
      end
    end
  end
  def commands_if_edited_as edited_text
    FlEd::operation_list_to_bash(operation_list_if_edited_as(edited_text))
  end
end

if __FILE__==$0
  Dir[File.join(File.dirname(__FILE__),'./test_*.rb')].each do |test_file|
    require test_file
  end
end