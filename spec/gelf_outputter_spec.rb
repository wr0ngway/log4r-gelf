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
      
      opts = ["127.0.0.1", 12201, 'LAN', {}]
      notifier = GELF::Notifier.new(*deep_copy(opts))
      GELF::Notifier.should_receive(:new).with(*opts).and_return(notifier)
      notifier.should_receive(:level_mapping=).with(:direct)
      
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
              level_mapping: logger
      EOF

      opts = ["myserver",
              1234,
              'WAN',
              {
                  'host' => 'myhost',
                  'facility' => 'myfacility',
                  'level' => GELF::Levels::FATAL
              }]
      notifier = GELF::Notifier.new(*deep_copy(opts))
      GELF::Notifier.should_receive(:new).with(*opts).and_return(notifier)
      notifier.should_receive(:level_mapping=).with('logger')

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
        :level => Log4r::GelfOutputter::LEVELS_MAP['INFO'],
        "_logger" => "mylogger"
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
                pattern: '%C: %m'
                type: PatternFormatter
      EOF
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      notifier.should_receive(:notify!).with(
        :short_message => "mylogger: hello\n",
        :level => Log4r::GelfOutputter::LEVELS_MAP['INFO'],
        "_logger" => "mylogger"
      )
      Log4r::Logger['mylogger'].info("hello")
    end
    
    
    it "should allow configuration of levels from yml" do
      yml = <<-EOF
        log4r_config:
          pre_config:
            root:
              level: 'DEBUG'
          loggers:
            - name: "mylogger"
              level: WARN
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
      
      logger = Log4r::Logger['mylogger']
      sio = StringIO.new 
      logger.outputters << Log4r::IOOutputter.new("sbout", sio)

      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      
      notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "yesshow\n"
        args[:short_message].should_not == "noshow\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['WARN']
      end
      
      logger.debug("noshow")
      logger.warn("yesshow")
      sio.string.should =~ /yesshow/
      sio.string.should_not =~ /noshow/
    end
      
    it "should allow configuration of higher log levels than logger from yml" do
      yml = <<-EOF
        log4r_config:
          pre_config:
            root:
              level: 'DEBUG'
          loggers:
            - name: "mylogger"
              level: INFO
              outputters:
                - gelf
          outputters:
            - type: GelfOutputter
              name: gelf
              level: WARN
              formatter:
                pattern: '%m'
                type: PatternFormatter
      EOF
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      
      logger = Log4r::Logger['mylogger']
      sio = StringIO.new 
      logger.outputters << Log4r::IOOutputter.new("sbout", sio)

      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      
      notifier.instance_eval { @sender }.should_not_receive(:send_datagrams)
      logger.info("semishow")
      sio.string.should =~ /semishow/
    end  

    it "should allow configuration of lower log levels than logger from yml" do
      yml = <<-EOF
        log4r_config:
          pre_config:
            root:
              level: INFO
          loggers:
            - name: "base"
              outputters:
                - gelf
            - name: "base::child"
              level: ERROR
          outputters:
            - type: GelfOutputter
              name: gelf
              level: WARN
              formatter:
                pattern: '%m'
                type: PatternFormatter
      EOF
      
      cfg = Log4r::YamlConfigurator
      cfg.load_yaml_string(yml)
      
      logger = Log4r::Logger['base::child']
      sio = StringIO.new 
      logger.outputters << Log4r::IOOutputter.new("sbout", sio)

      outputter = Log4r::Outputter['gelf']
      notifier = outputter.instance_eval { @notifier }
      sender = notifier.instance_eval { @sender }
      
      sender.should_not_receive(:send_datagrams)
      logger.warn("semishow")
      sio.string.should_not =~ /semishow/
    end  
    
  end
  
  context "log contents" do
    
    before(:each) do
      Log4r::GDC.set(nil)
      Log4r::NDC.clear
      Log4r::MDC.get_context.keys.each {|k| Log4r::MDC.remove(k) }
      
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
    
    it "passes logger as custom gelf attribute" do
      @notifier.should_receive(:notify!) do |args|
        args["_logger"].should == 'mylogger'
      end
      @logger.info("logger")
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
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "fatal\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['FATAL']
      end
      
      @logger.debug("debug")
      @logger.info("info")
      @logger.warn("warn")
      @logger.error("error")
      @logger.fatal("fatal")
    end
    
    it "extracts exception stack traces" do
      @notifier.should_receive(:notify!) do |args|
        args["_exception"].should == "StandardError"
        args[:short_message].should == "Caught StandardError: mybad"
        args[:full_message].should =~  /gelf_outputter_spec.rb:\d+/
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['ERROR']
        args[:file].should =~ /^\/.*gelf_outputter_spec.rb$/
        args[:line].should =~ /\d+/
      end
      ex = StandardError.new("mybad")
      raise ex rescue nil
      @logger.error(ex)
    end
    
    it "doesn't set file/line by default" do
      @logger.fatal("no tracing")
      notifier_hash = @notifier.instance_eval { @hash }
      notifier_hash['file'].should be_nil
      notifier_hash['line'].should be_nil
    end
    
    it "sets file/line if tracing" do
      @logger.trace = true
      @logger.fatal("no tracing")
      notifier_hash = @notifier.instance_eval { @hash }
      notifier_hash['file'].should_not be_nil
      notifier_hash['line'].should_not be_nil
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
    
    it "uses global log4r context if available" do
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "context\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['INFO']
        args["_global_context"].should == '"mygdc"'
      end
      Log4r::GDC.set("mygdc")
      @logger.info("context")
    end
    
    it "uses nested log4r context if available" do
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "context\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['INFO']
        args["_nested_context_0"].should == '"myndc0"'
        args["_nested_context_1"].should == '99'
      end
      Log4r::NDC.push("myndc0")
      Log4r::NDC.push(99)
      @logger.info("context")
    end
    
    it "uses mapped log4r context if available" do
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "context\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['INFO']
        args["_mapped_context_foo"].should == '"mymdcfoo"'
        args["_mapped_context_lucky"].should == '7'
      end
      Log4r::MDC.put("foo", "mymdcfoo")
      Log4r::MDC.put("lucky", 7)
      @logger.info("context")
    end
    
    it "handle failure inspecting log4r context" do
      o = Object.new
      o.stub(:inspect).and_raise("bad")
      @notifier.should_receive(:notify!) do |args|
        args[:short_message].should == "context\n"
        args[:level].should == Log4r::GelfOutputter::LEVELS_MAP['INFO']
        args.has_key?("_global_context").should be_false
        args.keys.grep(/_nested_context/).should == []
        args.keys.grep(/_mapped_context/).should == []
      end
      Log4r::GDC.set(o)
      Log4r::NDC.push(o)
      Log4r::MDC.put("obj", o)
      @logger.info("context")
    end
  end

end
