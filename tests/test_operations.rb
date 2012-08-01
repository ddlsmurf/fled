if Kernel.respond_to?(:require_relative)
  require_relative "helper"
else
  require File.join(File.dirname(__FILE__), 'helper')
end
require 'test/unit'

class TestSwapOperations < Test::Unit::TestCase
  def test_swap_renames
    ops = TestFS.new do
      truc.a.txt(1)
      truc.b.txt(2)
    end.operations_if_edited_as <<-TEST
      truc.a.txt :2
      truc.b.txt :1
    TEST
    assert_equal [
      [:mv, "truc.b.txt", "truc.a.txt.tmp"],
      [:mv, "truc.a.txt", "truc.b.txt"],
      [:mv, "truc.a.txt.tmp", "truc.a.txt"]
    ], ops
  end
  def test_swap_renames_warn_overwrite
    ops = TestFS.new do
      truc.a.txt(1)
      truc.b.txt(2)
    end.operations_if_edited_as <<-TEST
      truc.a.txt :2
    TEST
    
    assert_equal 2, ops.count
    assert_equal 4, ops.first.count
    assert_equal :warn, ops.first[0]
    assert_equal :would_overwrite, ops.first[1]
    assert_equal [:mv, "truc.b.txt", "truc.a.txt.tmp"], ops.last
  end
  def test_swap_renames_warn_overwrite_fallback
    ops = TestFS.new do
      truc.a.txt(1)
      truc.b.txt(2)
      truc.a.txt.tmp(3)
    end.operations_if_edited_as <<-TEST
      truc.a.txt :2
    TEST
    
    assert_equal 2, ops.count
    assert_equal 4, ops.first.count
    assert_equal :warn, ops.first[0]
    assert_equal :would_overwrite, ops.first[1]
    assert_equal [:mv, "truc.b.txt", "truc.a.txt.tmp.tmp"], ops.last
  end
  def test_swap_parents
    ops = TestFS.new do
      folder(0) {
        subfolder(1) {
          file(2)
        }
      }
    end.operations_if_edited_as <<-TEST
      subfolder :1
        folder :0
          file :2
    TEST
    assert_equal [
      [:mv, "folder/subfolder", "subfolder"],
      [:mv, "folder", "subfolder/folder"],
      [:mv, "subfolder/file", "subfolder/folder/file"]
     ], ops
  end
end

class TestOperationErrors < Test::Unit::TestCase
  def test_missing_uid_should_fail
    ops = TestFS.new { folder(0) }.operations_if_edited_as <<-TEST
      folder  :5
        something_else
    TEST
    assert_equal 1, ops.count
    assert_equal 3, ops.first.count
    assert_equal :fail, ops.first[0]
    assert_equal :no_such_uid, ops.first[1]
  end
end

class TestOperationExample < Test::Unit::TestCase
  def test_nanana

    ops = TestFS.new { 
    folder(0) {
      file_one(1)
      folder_two(2) {
        file_three(3)
      }
    } }.operations_if_edited_as <<-TEST
    folder_new/          :0
      new_folder/
        first    :1
        second   :3
      :2
    TEST
    assert_equal [
      [:mv, "folder", "folder_new"],
      [:mkdir, "folder_new/new_folder"],
      [:mv, "folder_new/file_one", "folder_new/new_folder/first"],
      [:mv, "folder_new/folder_two/file_three", "folder_new/new_folder/second"],
      [:rmdir, "folder_new/folder_two"],
    ], ops
  end
end
class TestOperations < Test::Unit::TestCase
  def setup
    @fs = TestFS.new do
      folder(0) {
        sous(1) {
          truc(2)
        }
        truc.txt(3)
      }
    end
  end
  def test_rename
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        sous :1
          truche :2
      truc.txt :3
    TEST
    assert_equal [[:mv, 'folder/sous/truc', 'folder/sous/truche']], ops
  end
  def test_rename_impact_on_mkdir
    ops = @fs.operations_if_edited_as <<-TEST
      folder_renamed :0
        machin
    TEST
    assert_equal [[:mv, "folder", "folder_renamed"], [:mkdir, "folder_renamed/machin"]], ops

  end
  def test_rename_impact_on_delete
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        soupe :1
           :2
        truc.txt :3
    TEST
    assert_equal [[:mv, 'folder/sous', 'folder/soupe'], [:rm, 'folder/soupe/truc']], ops
  end
  def test_rename_impact_on_reparent
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        soupe :1
        truc :2
        truc.txt :3
    TEST
    assert_equal [[:mv, 'folder/sous', 'folder/soupe'], [:mv, 'folder/soupe/truc', 'folder/truc']], ops
  end
  def test_reparent
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        truc :2
    TEST
    assert_equal [[:mv, 'folder/sous/truc', 'folder/truc']], ops
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
      truc :2
    TEST
    assert_equal [[:mv, 'folder/sous/truc', 'truc']], ops
  end
  def test_reparent_impact_on_mkdir
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
      sous :1
        machin
    TEST
    assert_equal [[:mv, "folder/sous", "sous"], [:mkdir, "sous/machin"]], ops
  end
  def test_reparent_impact_on_delete
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
      sous :1
      :2
    TEST
    assert_equal [[:mv, 'folder/sous', 'sous'], [:rm, 'sous/truc']], ops
  end
  def test_create_folder
    ops = @fs.operations_if_edited_as <<-TEST
      new
        subnew
      folder :0
        another
    TEST
    assert_equal [[:mkdir, 'new'], [:mkdir, "folder/another"], [:mkdir, 'new/subnew']], ops
  end
  def test_delete_folder
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        :1
        truc.txt :3
    TEST
    assert_equal [[:rmdir, 'folder/sous']], ops
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        :1
        :2
        truc.txt :3
    TEST
    assert_equal [[:rm, 'folder/sous/truc'], [:rmdir, 'folder/sous']], ops
  end
  def test_delete_file
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        sous :1
              :2
        truc.txt :3
    TEST
    assert_equal [[:rm, 'folder/sous/truc']], ops
  end
  def test_noop
    ops = @fs.operations_if_edited_as <<-TEST
      folder :0
        sous :1
          truc :2
      truc.txt :3
    TEST
    assert_equal [], ops
    ops = @fs.operations_if_edited_as <<-TEST
    TEST
    assert_equal [], ops
  end
end