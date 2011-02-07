A Log4r appender for logging to a gelf sink, e.g. the graylog2 server - http://www.graylog2.org

To use, require the gem before you setup log4r, then add config like the following to your log4r.yml:

    log4r_config:
      pre_config:
        root:
          level: 'DEBUG'
      loggers:
        - name: "rails"
          outputters:
            - gelf

      outputters:
        - type: GelfOutputter
          name: gelf
          gelf_server: "<%= graylog_server.full_name %>"
          gelf_port: "<%= rubber_env.graylog_server_port %>"
          # Optional - showing default values
          # facility: "gelf-rb"
          # host: "#{Socket.gethostname}"
          # max_chunk_size: 'LAN'
          # level: 5 # GELF::UNKNOWN
