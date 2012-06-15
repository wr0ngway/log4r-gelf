require 'gelf'
require 'log4r/outputter/outputter'

module Log4r

    class GelfOutputter < Log4r::Outputter

      LEVELS_MAP = {
        "DEBUG"  => GELF::Levels::DEBUG,
        "INFO"   => GELF::Levels::INFO,
        "WARN"   => GELF::Levels::WARN,
        "ERROR"  => GELF::Levels::ERROR,
        "FATAL"  => GELF::Levels::FATAL,
      }

      def initialize(_name, hash={})
        super(_name, hash)

        server = hash['gelf_server'] || "127.0.0.1"
        port = (hash['gelf_port'] || 12201).to_i
        max_chunk_size = hash['max_chunk_size'] || 'LAN'
        opts = {}
        opts['host'] = hash['host'] if hash['host']
        opts['facility'] = hash['facility'] if hash['facility']
        opts['level'] = LEVELS_MAP[hash['level']] if hash['level']

        @notifier = GELF::Notifier.new(server, port, max_chunk_size, opts)
        # Only collect file/line if user turns on trace in log4r config
        @notifier.collect_file_and_line = false
        @notifier.level_mapping = hash['level_mapping'] || :direct
      end

      private
      
      def canonical_log(logevent)

        opts = {}
        level = LEVELS_MAP[Log4r::LNAMES[logevent.level]]
        level = GELF::Levels::DEBUG unless level 
        opts[:level] = level
        opts["_logger"] = logevent.fullname
            
        if logevent.data.respond_to?(:backtrace)
          trace = logevent.data.backtrace
          if trace
            opts["_exception"] = "#{logevent.data.class}"
            opts[:short_message] = "Caught #{logevent.data.class}: #{logevent.data.message}"
            opts[:full_message] = "Backtrace:\n" + trace.join("\n")
            opts[:file] = trace[0].split(":")[0]
            opts[:line] = trace[0].split(":")[1]
          end
        end

        if logevent.tracer
          trace = logevent.tracer.join("\n")
          opts[:full_message] = "#{opts[:full_message]}\nLog tracer:\n#{trace}"
          opts[:file] = logevent.tracer[0].split(":")[0]
          opts[:line] = logevent.tracer[0].split(":")[1]
        end
        
        gdc = Log4r::GDC.get
        if gdc && gdc != $0
          begin
            opts["_global_context"] = gdc.inspect
          rescue
          end
        end
          
        if Log4r::NDC.get_depth > 0
          Log4r::NDC.clone_stack.each_with_index do |x, i|
            begin
              opts["_nested_context_#{i}"] = x.inspect
            rescue
            end
          end
        end

        mdc = Log4r::MDC.get_context
        if mdc && mdc.size > 0
          mdc.each do |k, v|
            begin
              opts["_mapped_context_#{k}"] = v.inspect
            rescue
            end
          end
        end
        
        synch do
          opts[:short_message] = format(logevent) unless opts[:short_message]
  
          @notifier.notify!(opts)
        end
      rescue => err
        puts "Graylog2 logger. Could not send message: " + err.message
        puts err.backtrace.join("\n") if err.backtrace
      end

    end

end
