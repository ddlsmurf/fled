#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__),'../lib')
require 'fled'

class TestListingBuilder < FlEd::FileListingBuilder
  def next_uid
    @uid
  end
  def enter dir, uid = nil
    @uid = uid
    super dir.to_s
  end
  def add name, uid
    @uid = uid
    super name, current_path(name.to_s)
  end
end

class TestFS
  def initialize &block
    @root = DTC::Utils::Visitor::DSL::accept(DTC::Utils::Visitor::HashBuilder, &block).root
  end
  def receive visitor, root = @root
    root.each_pair do |name, val|
      next if name.nil?
      if val.is_a?(Array)
        visitor.add name, val[0]
      elsif val.is_a?(Hash)
        if visitor.enter(name, val[nil][0])
          receive(visitor, val)
          visitor.leave
        end
      else
        raise RuntimeError, "Unknown value #{val.inspect}"
      end
    end
  end
  def new_builder
    builder = TestListingBuilder.new
    builder.enter("$")
    receive builder
    builder.leave
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