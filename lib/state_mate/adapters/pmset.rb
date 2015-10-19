require 'cmds'
require 'nrser'
require 'pp'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::PMSet
  # whitelist of modes we handle mapped to their `pmset` flag
  #
  # there is also a UPS mode, but i don't know what it looks like
  #
  MODES = {
    'Battery Power' => 'b',
    'AC Power' => 'c',
  }
  
  # a whitelist of settings to parse, since the output of `pmset -g custom`
  # can include lines like
  # 
  #     Sleep On Power Button 1
  # 
  # which makes it hard to parse in general (spaces in key name and between
  # key name and value).
  # 
  # from
  #
  # -   `man pmset
  # -   <https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/pmset.1.html>
  # 
  SETTINGS = [
    # display sleep timer; replaces 'dim' argument in 10.4 (value in minutes,
    # or 0 to disable)
    'displaysleep',
    
    # disk spindown timer; replaces 'spindown' argument in 10.4 (value in 
    # minutes, or 0 to dis-able)
    'disksleep',
    
    # system sleep timer (value in minutes, or 0 to disable)
    'sleep',
    
    # wake on ethernet magic packet (value = 0/1)
    'womp',
    
    # wake on modem ring (value = 0/1)
    'ring',
    
    # automatic restart on power loss (value = 0/1)
    'autorestart',
    
    # wake the machine when the laptop lid (or clamshell) is opened
    # (value = 0/1)
    'lidwake',
    
    # wake the machine when power source (AC/battery) is changed (value = 0/1)
    'acwake',
    
    # slightly turn down display brightness when switching to this power source
    # (value = 0/1)
    'lessbright',
    
    # display sleep will use an intermediate half-brightness state between full 
    # brightness and fully off  (value = 0/1)
    'halfdim',
    
    # use Sudden Motion Sensor to park disk heads on sudden changes in G force
    # (value = 0/1)
    'sms',
    
     # change hibernation mode. Please use caution. (value = integer)
    'hibernatemode',
    
    # change hibernation image file location. Image may only be located on the 
    # root volume. Please use caution. (value = path)
    'hibernatefile',
    
    # prevent idle system sleep when any tty (e.g. remote login session) is 
    # 'active'. A tty is 'inactive' only when its idle time exceeds the system 
    # sleep timer. (value = 0/1)
    'ttyskeepawake',          
    
    # this setting affects how OS X networking presents shared network services 
    # during system sleep. This setting is not used by all platforms; changing 
    # its value is unsupported.
    # 
    # ...so we won't support it
    # 'networkoversleep',
    
    # Destroy File Vault Key when going to standby mode. By default File vault
    # keys are retained even when system goes to standby. If the keys are
    # destroyed, user will be prompted to enter the password while coming out
    # of standby mode.(value: 1 - Destroy, 0 - Retain)
    'destroyfvkeyonstandby',
    
    # Where supported, enabled per default as an implementation of Lot 6 to the 
    # European Energy-related Products Directive. After sleeping for 
    # <autopoweroffdelay> minutes, the system will write a hibernation image 
    # and go into a lower power chipset sleep. Wakeups from this state will take
    # longer than wakeups from regular sleep. The system will not auto power
    # off if any external devices are connected, if the system is on battery 
    # power, or if the system is bound to a network and wake for net-work
    # network work access is enabled.
    'autopoweroff',
    
    # delay before entering autopoweroff mode. (Value = integer, in minutes)
    'autopoweroffdelay',
    
    # STANDBY ARGUMENTS
    
    # standby causes kernel power management to automatically hibernate a
    # machine after it has slept for a specified time period. This saves power
    # while asleep. This setting defaults to ON for supported hardware.
    # The setting standby will be visible in pmset -g if the feature is 
    # supported on this machine.
    # 
    # only works if hibernation is turned on to hibernatemode 3 or 25.
    'standby', 
    
    # specifies the delay, in seconds, before writing the hibernation image
    # to disk and powering off memory for Standby.
    'standbydelay',
    
    # UNDOCUMENTED ARGUMENTS
    
    # the "Power Nap" feature..?
    # 
    # http://apple.stackexchange.com/questions/116348/how-can-i-enable-and-or-disable-os-xs-power-nap-feature-from-within-terminal
    # 
    'darkwakes',
    
    # unknown
    # 'gpuswitch',
    
    # shows up on my imac. not even sure you can set it with pmset, so ignoring
    # for now
    # 'Sleep On Power Button',
  ]
  
  # regexp to pick the mode headers out of `pmset -g custom` output
  MODE_RE = /^(#{ MODES.keys.map {|_| Regexp.escape _ }.join('|') })\:$/
  
  # regexp to pick the settings and values out of other lines of
  # `pmset -g custom`
  SETTING_RE = /^\s(#{ SETTINGS.map {|_| Regexp.escape _ }.join '|' })\s+(.*)$/
  
  # @api util
  # *pure*
  # 
  # parse the output of `pmset -g custom`.
  # 
  # since keys can apparently have spaces in them
  # (like "Sleep On Power Button") and are seperated by spaces, it uses
  # the {.SETTINGS} whitelist.
  # 
  # settings are saved at
  # 
  #     /Library/Preferences/SystemConfiguration/com.apple.PowerManagement.plist
  # 
  # which might be a possible site for reading and writing, but seems safer
  # to use `pmset`, and should satify needs for now.
  # 
  # @param input [String] output of `pmset -g custom`.
  #     on my mbp it looks like
  #     
  #         Battery Power:
  #           lidwake              1
  #           autopoweroff         1
  #           autopoweroffdelay    14400
  #           standbydelay         10800
  #           standby              1
  #           ttyskeepawake        1
  #           hibernatemode        3
  #           darkwakes            0
  #           gpuswitch            2
  #           hibernatefile        /var/vm/sleepimage
  #           displaysleep         5
  #           sleep                5
  #           acwake               0
  #           halfdim              1
  #           lessbright           0
  #           disksleep            10
  #         AC Power:
  #           lidwake              1
  #           autopoweroff         0
  #           autopoweroffdelay    0
  #           standbydelay         0
  #           standby              0
  #           ttyskeepawake        1
  #           hibernatemode        3
  #           darkwakes            1
  #           gpuswitch            0
  #           hibernatefile        /var/vm/sleepimage
  #           womp                 0
  #           displaysleep         5
  #           networkoversleep     0
  #           sleep                10
  #           acwake               0
  #           halfdim              1
  #           disksleep            10
  # 
  # @return [Hash<String, Hash<String, String>>] hash of section titles 
  #     (like "Battery Power") to hashes of string keys to *sting* values
  #     (does not turn numeric strings into integers).
  def self.parse input
    sections = {}
    section = {}
    
    input.lines.each do |line|
      if m = line.match(MODE_RE)
        section = {}
        sections[m[1]] = section
      else
        if m = line.match(SETTING_RE)
          section[m[1]] = m[2]
        end
      end
    end
    sections
  end
  
  # @api adapter
  # 
  # reads pm settings.
  # 
  # @param key [Array<String>] key path to read:
  #     -   `[]` gets everything, returning a hash
  #         `{<mode> => {<setting> => <value>}}`.
  #         
  #         `PMSet.read []` looks something like:
  #         
  #             {"Battery Power"=>
  #               {"lidwake"=>"1",
  #                "autopoweroff"=>"1",
  #                ...},
  #              "AC Power"=>
  #               {"lidwake"=>"1",
  #                "autopoweroff"=>"1",
  #                ...}}
  #     
  #     
  #     -   `[<mode>]` gets a hash of `{<setting> => <value>}` for that mode.
  #         
  #         `PMSet.read ["AC Power"]` looks something like:
  #         
  #             {"lidwake"=>"1",
  #              "autopoweroff"=>"1",
  #              ...}
  #         
  #     -   `[<mode>, <setting>]` gets a string value.
  #         
  #         `PMSet.read ["AC Power", "lidwake"]` looks something like `"1"`
  # 
  #     in addition
  #     -     `<mode>` must be in the keys of {.MODES}
  #     -     `<setting>` must be in {.SETTINGS}
  # 
  # @return [Hash<String, Hash<String, String>>] hash of everything when
  #         `key` is `[]`
  # @return [Hash<String, String>] hash of values for mode when `key` is
  #         `[<mode>]`
  # @return [String] value when `key` is `[<mode>, <setting>]`
  # 
  # @raise [ArgumentError] if the key is not found.
  # 
  def self.read key, options = {}
    # read all the settings.
    settings = parse Cmds.out!('pmset -g custom')
    
    value = settings
    key.each do |seg|
      unless value.key? seg
        raise ArgumentError.new binding.erb <<-END
          bad segment #{ seg.inspect } in key #{ key }.
          
          pm settings:
          
          <%= settings.pretty_inspect %>
        END
      end
      value = value[seg]
    end
    
    value
  end
  
  # @api adapter
  # 
  # writes pm settings.
  # 
  # @param key [Array<String>] must be a two-element array of strings where
  #     the first element is a key of {.MODES} and the second is in {.SETTINGS}.
  # @param value [String] value to write.
  # 
  # @return nil
  #
  # @raise [ArgumentError] if `key` is bad.
  # 
  def self.write key, value, options = {}
    unless key.is_a?(Array) && key.length == 2
      raise ArgumentError.new binding.erb <<-END
        key must be a pair [mode, setting], not <%= key.inspect %>.
      END
    end
    
    mode, setting = key
    
    if MODES[mode].nil?
      raise ArgumentError.new binding.erb <<-END
        first key element must be one of
        
        <%= MODES.keys.pretty_inspect %>
        
        found <%= mode.inspect %>
      END
    end
    
    unless SETTINGS.include? setting
      raise ArgumentError.new binding.erb <<-END
        second key element must be one of
        
        <%= SETTINGS.pretty_inspect %>
        
        found <%= setting.inspect %>
      END
    end
    
    Cmds! "sudo pmset -#{ MODES[mode] } %{setting} %{value}",
      setting: setting,
      value: value
    
    nil
  end
end # PMSet
