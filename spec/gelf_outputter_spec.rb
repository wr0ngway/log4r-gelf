require "spec_helper"

describe Log4r::GelfOutputter do

  context "log4r yaml configuration" do

    it "has default values without configuration" do
      yml = <<-EOF
        log4r_config:
          pre_config:
            root:
              level: 'DEBUG'
          loggers:
            - name: "mylogger"
              outputters:
                - gelf
        
          outputters:
            - type: GelfOutputter
              name: gelf
      EOF
      
      GELF::Notifier.should_receive(:new).with("127.0.0.1", 12201, 'LAN', {})
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      outputter = Log4r::Outputter['gelf']
      outputter.should_not be_nil
    end

    it "honors configuration values" do
      yml = <<-EOF
        log4r_config:
          pre_config:
            root:
              level: 'DEBUG'
          loggers:
            - name: "mylogger"
              outputters:
                - gelf
    
          outputters:
            - type: GelfOutputter
              name: gelf
              gelf_server: "myserver"
              gelf_port: "1234"
              facility: "myfacility"
              host: "myhost"
              max_chunk_size: 'WAN'
              level: FATAL
      EOF
      
      GELF::Notifier.should_receive(:new).with("myserver",
                                               1234,
                                               'WAN',
                                               {
                                                 'host' => 'myhost',
                                                 'facility' => 'myfacility',
                                                 'level' => GELF::Levels::FATAL
                                               }
      )
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      outputter = Log4r::Outputter['gelf']
      outputter.should_not be_nil
    end

  end

end
