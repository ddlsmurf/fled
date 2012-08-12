module FlEd
  class FileListingBuilder
    attr_accessor :listing
    def initialize listing = FileListing.new
      @listing = listing
      @folders = []
    end
    def add_object path, dir
      uid = next_uid
      name = File.basename(path)
      object = @listing.add(uid,
        :path => path,
        :name => File.basename(path),
        :parent => @object_stack.last,
        :line => "#{"  " * depth}#{name}#{dir ? "/" : ""}"
      )
      object[:dir] = true if dir
      object
    end
    def depth ; @folders.count ; end
    def full_path *args ; File.join((@folders || []) + args) ; end
    def enter dir
      if depth.zero?
        @object_stack = []
      else
        @object_stack.push add_object(dir, true)
      end
      @folders << dir
      true
    end
    def add name, full_path
      add_object full_path, false
    end
    def leave
      @object_stack.pop
      @folders.pop
    end
    protected
    def next_uid
      @listing.count
    end
  end
end