require 'pp'

require 'CFPropertyList'

require 'nrser'
require 'nrser/exec'

require 'state_mate'

using NRSER

module StateMate::Adapters::TimeMachine
  include StateMate::Adapters
  register 'time_machine'
  
  EXE = '/usr/bin/tmutil'
  PLIST_PATH = '/Library/Preferences/com.apple.TimeMachine.plist'

  def self.local_enabled?
    # seems to change the key
    #
    #     /Library/Preferences/com.apple.TimeMachine.plist:MobileBackups
    # 
    plist = CFPropertyList::List.new file: PLIST_PATH
    data = CFPropertyList.native_types plist.value
    data['MobileBackups']
  end

  def self.enable_local
    NRSER::Exec.run "%{exe} enablelocal", exe: EXE
  end

  def self.disable_local
    NRSER::Exec.run "%{exe} disablelocal", exe: EXE
  end

  def self.read key, options = {}
    case key
    when 'local_backups'
      local_enabled?
    else
     raise "bad key: #{ key.inspect }"
    end
  end

  def self.write key, value, options = {}
    case key
    when 'local_backups'
      case value
      when true
        enable_local
      when false
        disable_local
      else
        raise "bad value: #{ value.inspect }"
      end
    else
      raise "bad key: #{ key.inspect }"
    end
  end

end # TimeMachine