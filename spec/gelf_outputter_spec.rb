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
    
    it "works without a formatter" do
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
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      notifier.should_receive(:notify!).with(
        :short_message => " INFO mylogger: hello\n",
        :full_message => nil,
        :level => Log4r::GelfOutputter::LEVELS_MAP['INFO'],
        :file => nil,
        :line => nil
      )
      Log4r::Logger['mylogger'].info("hello")
    end

    it "uses formatter if given" do
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
              formatter:
                pattern: '%C [%x]: %m'
                type: PatternFormatter
      EOF
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      notifier.should_receive(:notify!).with(
        :short_message => "mylogger [foobar]: hello\n",
        :full_message => nil,
        :level => Log4r::GelfOutputter::LEVELS_MAP['INFO'],
        :file => nil,
        :line => nil
      )
      Log4r::NDC.push("foobar")
      Log4r::Logger['mylogger'].info("hello")
    end
  
  end
  
  context "log contents" do
    
    before(:each) do
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
              formatter:
                pattern: '%m'
                type: PatternFormatter
      EOF
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      @outputter = Log4r::Outputter['gelf']
      @notifier = @outputter.instance_eval { @notifier }
      @logger = Log4r::Logger['mylogger']
    end
    
    it "uses log levels" do
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "debug\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['DEBUG']
      end
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "info\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['INFO']
      end
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "warn\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['WARN']
      end
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "error\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['ERROR']
      end
      
      @logger.debug("debug")
      @logger.info("info")
      @logger.warn("warn")
      @logger.error("error")
    end
    
    it "extracts exception stack traces" do
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "mybad\n"
        args[:full_message].should =~  /gelf_outputter_spec.rb:\d+/
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['ERROR']
        args[:file].should =~ /^\/.*gelf_outputter_spec.rb$/
        args[:line].should =~ /\d+/
      end
      ex = StandardError.new("mybad")
      raise ex rescue nil
      @logger.error(ex)
    end
    
    it "uses trace data if enabled" do
      @logger.trace = true
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "tracing\n"
        args[:full_message].should =~  /Log tracer:\n.*gelf_outputter_spec.rb:\d+/
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['ERROR']
        args[:file].should =~ /^\/.*gelf_outputter_spec.rb$/
        args[:line].should =~ /\d+/
      end
      @logger.error("tracing")
    end
    
  end

end
