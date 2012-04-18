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
      end

      private
      
      def canonical_log(logevent)
        
        level = LEVELS_MAP[Log4r::LNAMES[logevent.level]]
        level = GELF::Levels::DEBUG unless level 

        if logevent.data.respond_to?(:backtrace)
          trace = logevent.data.backtrace
          if trace
            full_msg = trace.join("\n")
            file = trace[0].split(":")[0]
            line = trace[0].split(":")[1]
          end
        end

        if logevent.tracer
          trace = logevent.tracer.join("\n")
          full_msg = "#{full_msg}\nLog tracer:\n#{trace}"
          file = logevent.tracer[0].split(":")[0]
          line = logevent.tracer[0].split(":")[1]
        end

        synch do
          msg = format(logevent)
  
          @notifier.notify!(
            :short_message => msg,
            :full_message => full_msg,
            :level => level,
            :file => file,
            :line => line
          )
        end
      rescue => err
        puts "Graylog2 logger. Could not send message: " + err.message
        puts err.backtrace.join("\n") if err.backtrace
      end

    end

end
