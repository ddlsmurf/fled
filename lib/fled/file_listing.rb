module FlEd
  # In memory tree structure for storing
  # a file-system
  class FileListing
    def initialize
      @objects_by_id = {}
      @objects = []
      @errors = []
    end
    attr_accessor :errors
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
      listing.split("\n").each_with_index do |line, line_number|
        next if line.strip.empty?
        raise RuntimeError, "Unparsable line #{line.inspect}" unless line =~ /^((?: )*)(.*?)(?::(\d+))?\r?$/
        indent = $1
        name = $2.strip
        if (dir = name[-1..-1] == "/")
          name = name[0..-2]
        end
        current = nil
        begin
          current = objects.add($3, :name => name, :line => "#{$1}#{$2}")
        rescue Exception => e
          (objects.errors ||= []) << [:fail,
            :duplicate_uid, {:name => name, :line_number => line_number + 1}
          ]
        end
        next unless current
        current[:dir] = true if dir
        next if name.strip == "" # Ignore indent when there is no name - element will be deleted, parent isnt used
        if previous_indent && previous_indent != indent
          if previous_indent.length < indent.length
            stack.push(previous)
          else
            stack.pop
          end
        end
        current[:line_number] = line_number + 1
        current[:parent] = stack.last if stack.count > 0
        previous = current
        previous_indent = indent
      end
      objects
    end
  end
  class FileListing # Shell operation list builder
    # Generate a list of operations that
    # would transform the `source_listing`
    # into the receiver.
    #
    # Result is an array with each entry of
    # the format:
    #
    # - `[:fail, reason_symbol, target]`
    # - `[:warn, reason_symbol, target]`
    # - `[:mk, [path components]]`
    # - `[:moved, [source path components], [dest path components]]`
    # - `[:renamed, [source path components], new name]`
    # - `[:rm, [path components], source_object]`
    def operations_from! source_listing
      op_errors = []
      operations = []
      pending_renames = []
      running_source = source_listing.dup
      self.breadth_first do |target, path|
        next if path.any? { |o| o[:error] }
        if target[:name] != "" && !target[:uid]
          operations << [:mk, self.path_of(target).map { |o| o[:name] }]
          fake_source = {:name => target[:name], :dir => true}
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
            op_errors += [[:fail, :no_such_uid, target]]
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
            if (target_parent = target[:parent])
              until !target_parent || !target_parent[:source] || target_parent[:source][:dir]
                target_parent = target_parent[:parent]
              end
            end
            source_path = running_source.path_of(source).map { |o| o[:name] }
            target[:name] = source[:name] = new_name
            operations << [:moved,
              source_path,
              self.path_of(target_parent).map { |o| o[:name] } + [target[:name]]
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
          op_errors += [[:warn, :would_overwrite, target,
            running_source.path_of(target[:parent]).map { |o| o[:name] } + [new_name]]]
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
          operation = target[:source][:dir] ? :rmdir : :rm
          operations << [operation, running_source.path_of(target[:source]).map { |o| o[:name] }, target[:source]]
        end
      end
      errors + op_errors + operations
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
end