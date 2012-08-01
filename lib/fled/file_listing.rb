module FlEd
  class FileListing
    def initialize
      @objects_by_id = {}
      @objects = []
    end
    RELATION_KEYS = [:parent]
    def dup
      result = self.class.new
      each do |object|
        result.add object[:uid], object.dup
      end
      result.each do |object|
        RELATION_KEYS.each do |relation|
          next unless foreign = object[relation]
          unless foreign[:uid]
            raise RuntimeError, "Cannot duplicate anonymous object and maintain #{relation.inspect} referential"
          end
          unless (object[relation] = result[foreign[:uid]])
            raise RuntimeError, "Cannot duplicate object in #{relation.inspect} referential, no duplicate found in target (?!)"
          end
        end
      end
      result
    end
    def each &block ; @objects.each(&block) ; end
    def count ; @objects.count ; end
    def add uid, object = {}
      if uid
        uid = uid.to_s
        raise RuntimeError, "UID #{uid.inspect} already declared" if @objects_by_id[uid]
        @objects_by_id[uid] = object
        object[:uid] = uid
      end
      @objects << object
      object
    end
    def [](uid)
      if uid.is_a?(String)
        @objects_by_id[uid]
      else
        @objects[uid]
      end
    end
  end
  class FileListing # to and from text format
    def to_s
      return "" if @objects.empty?
      max_width = @objects.map { |o| o[:line] }.map(&:length).max + 10
      @objects.map { |e| "#{e[:line].ljust(max_width)}:#{e[:uid]}" }.join("\n")
    end
    def self.parse listing
      objects = self.new
      previous_indent = nil
      previous = nil
      stack = []
      listing.split("\n").each do |line|
        next if line.strip.empty?
        raise RuntimeError, "Unparsable line #{line.inspect}" unless line =~ /^((?: )*)(.*?)(?::(\d+))?\r?$/
        indent = $1
        name = $2.strip
        if (dir = name[-1..-1] == "/")
          name = name[0..-2]
        end
        current = objects.add($3, :name => name, :line => "#{$1}#{$2}")
        current[:dir] = true if dir
        next if name.strip == "" # Ignore indent when there is no name - element will be deleted, parent isnt used
        if previous_indent && previous_indent != indent
          if previous_indent.length < indent.length
            stack.push(previous)
          else
            stack.pop
          end
        end
        current[:parent] = stack.last if stack.count > 0
        previous = current
        previous_indent = indent
      end
      objects
    end
  end
  class FileListing # Shell operation list builder
    def operations_from! source_listing
      errors = []
      operations = []
      pending_renames = []
      running_source = source_listing.dup
      self.breadth_first do |target, path|
        next if path.any? { |o| o[:error] }
        if target[:name] != "" && !target[:uid]
          operations << [:mk, self.path_of(target).map { |o| o[:name] }]
          fake_source = {:name => target[:name]}
          fake_source[:parent] = running_source[path.last[:source][:uid]] unless path.empty?
          target_uid = "new_#{running_source.count}"
          target_uid += "_" while @objects_by_id[target_uid] || running_source[target_uid]
          target[:uid] = target_uid
          @objects_by_id[target_uid] = target
          target[:source] = running_source.add(target_uid, fake_source)
        else
          source = running_source[target[:uid]]
          if !(target[:source] = source)
            target[:error] = true
            errors += [[:fail, :no_such_uid, target]]
            next
          end
          next if target[:name] == ""
          if (target[:parent] || {})[:uid] != (source[:parent] ||{})[:uid]
            existing_names = running_source.children_of((target[:parent] || {})[:uid]).map { |o| o[:name] }
            new_name = target[:name]
            new_name += ".tmp" while existing_names.any? { |n| n.casecmp(new_name) == 0 }
            if new_name != target[:name]
              pending_renames << [:renamed, target, target[:name]]
            end
            source_path = running_source.path_of(source).map { |o| o[:name] }
            target[:name] = source[:name] = new_name
            operations << [:moved,
              source_path,
              self.path_of(target).map { |o| o[:name] }
            ]
            if target[:parent]
              source[:parent] = running_source[target[:parent][:uid]]
            else
              source.delete(:parent)
            end
          elsif target[:name] != source[:name]
            source_path = running_source.path_of(source).map { |o| o[:name] }
            existing_names = running_source.children_of((target[:parent] || {})[:uid]).map { |o| o[:name] }
            new_name = target[:name]
            new_name += ".tmp" while existing_names.any? { |n| n.casecmp(new_name) == 0 }
            if new_name != target[:name]
              pending_renames << [:renamed, target, target[:name]]
            end
            target[:name] = source[:name] = new_name
            operations << [:renamed,
              source_path,
              target[:name]
            ]
          end
        end
      end
      pending_renames.each do |op|
        target = op[1]
        new_name = op[2]
        existing_names = running_source.children_of((target[:parent] || {})[:uid]).map { |o| o[:name] }
        if existing_names.any? { |n| n.casecmp(new_name) == 0 }
          errors += [[:warn, :would_overwrite, target, new_name]]
        else
          operations << [:renamed,
            running_source.path_of(target).map { |o| o[:name] },
            new_name
          ]
          target[:name] = target[:source][:name] = new_name
        end
      end
      self.depth_first do |target, path|
        if target[:name] == ""
          operations << [:rm, running_source.path_of(target[:source]).map { |o| o[:name] }, target[:source]]
        end
      end
      errors + operations
    end
    def has_child? parent, child
      while child = child[:parent]
        return true if child[:uid] == parent[:uid]
      end
      false
    end
    def path_name_of object
      File.join(path_of(object).map { |o| o[:name] })
    end
    def path_of object
      res = []
      while object
        res.unshift object
        object = object[:parent]
      end
      res
    end
    def children_of parent, &blk
      unless !parent || parent.is_a?(Hash)
        parent_object = self[parent]
        raise RuntimeError, "No parent #{parent.inspect} found" unless parent_object
        parent = parent_object
      end
      @objects.
      select { |e| (e[:parent].nil? && parent.nil?) || (e[:parent] == parent)  }.
      sort { |a, b| a[:name] <=> b[:name] }.
      each(&blk)
    end
    def depth_first parent = nil, path = [], &block
      children_of parent do |child|
        depth_first(child, path + [child], &block)
        yield child, path
      end
    end
    def breadth_first parent = nil, path = [], &block
      to_browse = []
      children_of parent do |child|
        yield child, path
        to_browse += [child]
      end
      to_browse.each { |child| breadth_first child, path + [child], &block }
    end
  end
  class ListingBuilder < DTC::Utils::FileVisitor
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
    def enter_folder dir
      depth = self.depth
      if self.depth == 0
        @object_stack = []
      else
        @object_stack.push add_object(dir, true)
      end
      super
    end
    def visit_file name, full_path
      add_object full_path, false
      super
    end
    def leave_folder
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