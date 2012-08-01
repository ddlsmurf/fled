module DTC
  module Utils
    # Small select(2) implementation
    class MiniSelect
      BUFSIZE = 4096
      def initialize &block # :yields: miniselect
        @want_read = {}
        @want_write = {}
        @want_close = {}
        @shutdown = false
        @stop_when_empty = true
        yield self if block_given?
      end
      attr_reader :shutdown
      # Default: True. Stops as soon as there are no more watched fds.
      attr_accessor :stop_when_empty
      # Shutdown the loop after this step
      def stop
        @shutdown = :requested_by_stop
      end
      # True if no items will be read or written (which also terminates the loop)
      def empty?
        @want_read.empty? && @want_write.empty?
      end
      # Add a file to monitor for reading.
      # When read events occur, provided block is yielded with event <code>:read</code>,
      # upon close it is yielded with event <code>:close</code>
      def add_read fd, &cb # :yields: miniselect, event, file, data_string
        @want_read[fd] = cb
      end
      # Write to specified fd in a non-blocking manner
      #
      # When write is completed, provided block is yielded with event <code>:done</code>,
      # upon close it is yielded with event <code>:close</code>
      def write fd, data, &cb # :yields: miniselect, event, file
        raise "Cannot write, FD is closed" if fd.closed?
        raise "Cannot write, FD is marked to close when finished" if @want_close[fd]
        (@want_write[fd] ||= []) << [data, cb]
      end
      # Provided block is called at every select(2) timeout or operation
      def every_beat &block # :yields: miniselect
        (@block ||= []) << block
      end
      # Provided block is called at every select(2) timeout
      def every_timeout &block # :yields: miniselect
        (@timeouts ||= []) << block
      end
      # Provided block is called at every read/write error
      def every_error &block # :yields: miniselect, fd, error
        (@error_handlers ||= []) << block
      end
      # Close the specified file, calling all callbacks as required, closing the
      # descriptor, and removing them from the miniselect
      def close_now fd, error = nil
        event_id = error ? :error : :close
        Array(@want_read.delete(fd)).each { |cb| cb.call(self, event_id, fd, error) if cb }
        Array(@want_write.delete(fd)).each { |data, cb| cb.call(self, event_id, fd, error) if cb }
        Array(@want_close.delete(fd)).each { |cb| cb.call(self, event_id, fd, error) }
        fd.close unless fd.closed?
        if error && @error_handlers
          Array(@error_handlers).each { |cb| cb.call(self, fd, error) }
        end
      end
      # Write to specified fd in a non-blocking manner
      #
      # When write is completed, the file is closed and the provided
      # block is yielded with event <code>:close</code>.
      def close fd, &cb # :yields: miniselect, event, file
        return if fd.closed?
        @want_close[fd] = cb
        if Array(@want_read[fd]).empty? && Array(@want_write[fd]).empty?
          close_now fd
        end
      end
      # Run the select loop, return when it terminates
      def run timeout = 5
        while !@shutdown && run_select(timeout)
          Array(@block).each { |cb| cb.call(self) } if @block
        end
      end
      # <code>self.new(&block).run(*args)</code>
      def self.run *args, &block
        self.new(&block).run(*args)
      end

      protected

      # Read data from fd without blocking, close on error
      # 
      # return [is_fd_active, data_read]
      def read_fd_nonblock fd
        res = ""
        can_goon = true
        error = nil
        while fd
          begin
            buf = fd.read_nonblock(BUFSIZE)
            res << buf if buf
            redo if buf && buf.length == BUFSIZE
          rescue Errno::EAGAIN
            break
          rescue EOFError => e
            can_goon = false
            break
          rescue SystemCallError => e
            can_goon = false
            error = e
            break
          end
        end
        @want_read[fd].call(self, :read, fd, res) if res != ""
        close_now(fd, error) unless can_goon
        [can_goon, res]
      end
      # Write data to fd in a non blocking way, close on error
      # 
      # return [is_fd_active, unwritten_data]
      def write_fd_nonblock fd, data, cb
        len = 0
        can_goon = true
        error = nil
        if fd
          begin
            wlen = fd.write_nonblock(data)
            len += wlen if wlen
          rescue Errno::EAGAIN
          rescue SystemCallError => e
            error = e
            can_goon = false
          end
        end
        complete = len == data.length
        if complete
          pdata, cb = @want_write[fd].shift
          cb.call(self, :done, fd) if cb
        elsif len > 0
          @want_write[fd].first[0] = data[len..-1]
        end
        close_now(fd, error) unless can_goon
        [can_goon, can_goon && complete]
      end
      # run one call to select, and resulting fd operations
      def run_select timeout
        if @stop_when_empty && empty?
          @shutdown = :no_active_fd
          return false
        end
        result = select(@want_read.keys, @want_write.keys,
          (@want_read.keys + @want_write.keys + @want_close.keys).uniq, timeout)
        if !result
          Array(@timeouts).each { |cb| cb.call(self) } if @timeouts
          return true
        end
        r, w, e = *result
        r.each do |readable|
          can_retry, data = read_fd_nonblock(readable)
        end
        w.each do |writable|
          queue = @want_write[writable]
          while !queue.empty?
            can_retry, is_write_complete = write_fd_nonblock(writable, *queue.first)
            break unless can_retry && is_write_complete
          end
          if queue.empty?
            @want_write.delete(writable)
            close_now writable if @want_close[writable]
          end
        end
        e.each do |erroredified|
          puts "#{erroredified} error"
          close erroredified
        end
        true
      end
    end
  end
end