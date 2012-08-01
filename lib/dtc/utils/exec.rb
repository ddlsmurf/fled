
require 'shellwords'
require 'open3'

module DTC
  module Utils
    # Execute a program with popen3, pipe data to-from a proc in an async loop
    #
    #     i = 10
    #     Exec.run("cat",
    #       :input => "Initial input\n",
    #       :select_timeout => 1,
    #       :autoclose_stdin => false
    #       ) do |process, sout, serr, writer|
    #       if writer && (i -= 1) > 0 && i % 2 == 0
    #         puts "Writing"
    #         writer.call("Hello async world!\n", lambda { |*args| puts "Write complete" })
    #       elsif writer && i <= 0
    #         puts "Closing stdin"
    #         writer.call(nil, lambda { |*args| puts "Close complete" })
    #       end
    #       puts "Got #{sout.inspect}" if sout != ""
    #     end
    class Exec
      class << self
        def sys *opts
          system(opts.flatten.map {|e| Shellwords::shellescape(e.to_s)}.join(" "))
          raise "External command error" unless $?.success?
        end
        def sys_in cwd, *opts
          Dir.chdir cwd { sys(*opts) }
        end
        def rsys *opts
          res = `#{opts.map {|e| Shellwords::shellescape(e.to_s)}.join(" ")}`
          $?.success? ? res : nil
        end
        def rsys_in cwd, *opts
          Dir.chdir cwd { rsys(*opts) }
        end
        def git *opts
          sys(*(%w[git] + opts))
        end
        def git_in cwd, *opts
          Dir.chdir(cwd) { git(*opts) }
        end
        def rgit *opts
          rsys(*(%w[git] + opts))
        end
        def rgit_in cwd, *opts
          Dir.chdir(cwd) { return rgit(*opts) }
        end
      end

      def initialize *cmd
        options = cmd.last.is_a?(Hash) ? cmd.pop() : {}
        @input = options.delete(:input)
        @autoclose_stdin = options.delete(:autoclose_stdin) { true }
        @cmd = cmd + options.delete(:cmd) { [] }
        @select_timeout = options.delete(:select_timeout) { 5 }
        @running = false
        @ran = false
      end
      attr_accessor :input
      attr_accessor :cmd
      attr_reader :ran, :running, :exec_time, :stdout, :stderr
      def run # :yields: exec, new_stdout, new_stderr, write_proc
        @start_time = Time.new
        @stdout = ""
        @stderr = ""
        @running = true
        stdin, stdout, stderr = Open3::popen3(*@cmd)
        begin
          stdout_read, stderr_read = "", ""
          MiniSelect.run(@select_timeout) do |select|
            writing = 0
            write_proc = lambda do |*args|
              text, callback = *args
              if text.nil?
                write_proc = nil
                select.close(stdin) do |miniselect, event, file, error|
                  callback.call(miniselect, event, file, error) if callback
                end
              else
                writing += 1
                select.write(stdin, text) do |miniselect, event, file, error|
                  if event == :error || event == :close
                    writing = 0
                    write_proc = nil
                  else
                    writing -= 1
                  end
                  callback.call(miniselect, event, file, error) if callback
                end
              end
            end
            select.add_read(stdout) do |miniselect, event, file, data_string|
              if data_string
                @stdout << data_string
                stdout_read << data_string
              end
            end
            select.add_read(stderr) do |miniselect, event, file, data_string|
              if data_string
                @stderr << data_string
                stderr_read << data_string
              end
            end
            select.every_beat do |miniselect|
              yield(self, stdout_read, stderr_read, write_proc) if block_given?
              if write_proc && writing == 0 && @autoclose_stdin
                select.close(stdin)
                write_proc = nil
              end
              stdout_read, stderr_read = "", ""
            end
            write_proc.call(@input) if @input
          end
          if stdout_read != "" || stderr_read != ""
            yield(self, stdout_read, stderr_read, nil) if block_given?
          end
        ensure
          [stdin, stdout, stderr].each { |f| f.close() if f && !f.closed? }
          @running = false
          @ran = true
        end
        @exec_time = Time.new - @start_time
      end
      # <code>self.new(&block).run(*args)</code>
      def self.run *args, &block
        self.new(*args).run(&block)
      end
    end
  end
end