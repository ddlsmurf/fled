module FlEd
  class FileListingBuilder < DTC::Utils::FileVisitor
    attr_accessor :listing
    def initialize listing = FileListing.new
      @listing = listing
    end
    def add_object path, dir
      uid = next_uid
      name = File.basename(path)
      object = @listing.add(uid,
        :path => path,
        :name => File.basename(path),
        :parent => @object_stack.last,
        :line => "#{"  " * self.depth}#{name}#{dir ? "/" : ""}"
      )
      object[:dir] = true if dir
      object
    end
    def enter dir
      depth = self.depth
      if self.depth == 0
        @object_stack = []
      else
        @object_stack.push add_object(dir, true)
      end
      super
    end
    def add name, full_path
      add_object full_path, false
      super
    end
    def leave
      @object_stack.pop
      super
    end
    protected
    def next_uid
      @listing.count
    end
    def source_path source
      res = []
      while source
        res.unshift target[:name]
        target = target[:parent]
      end
      File.join(res)
    end
    def target_path target
      res = []
      while target
        res.unshift target[:name]
        target = target[:parent]
      end
      File.join(res)
    end
  end
end