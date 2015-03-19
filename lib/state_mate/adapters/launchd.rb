require 'nrser'
require 'nrser/exec'

require 'state_mate'
require 'state_mate/adapters/defaults'

using NRSER

module StateMate::Adapters::LaunchD
  EXE = '/bin/launchctl'

  def self.loaded? label
    begin
      NRSER::Exec.run "%{exe} list -x %{label}", exe: EXE, label: label
    rescue SystemCallError => e
      false
    else
      true
    end
  end

  def self.parse_key key
    # use the same key seperation as Defaults
    StateMate::Adapters::Defaults.parse_key key
  end

  def self.load file_path
    NRSER::Exec.run "%{exe} load -w %{file_path}",  exe: EXE,
                                                    file_path: file_path
  end

  def self.unload file_path
    NRSER::Exec.run "%{exe} unload -w %{file_path}",  exe: EXE,
                                                      file_path: file_path
  end

  def self.read key, options = {}
    file_path, key_segs = parse_key key

    # get the hash of the plist at the file path and use that to get the label
    plist = StateMate::Adapters::Defaults.read file_path
    label = plist["Label"]

    case key_segs
    # the only thing we can handle right now
    when ['loaded']
      loaded? label
    else
      raise "unprocessable key: #{ key.inspect }"
    end
  end

  def self.write key, value, options = {}
    file_path, key_segs = parse_key key

    case key_segs
    when ['loaded']
      case value
      when true
        load file_path

      when false
        unload file_path

      else
        raise StateMate::Error::TypeError value, "expected true or false"

      end
    else
      raise "unprocessable key: #{ key.inspect }"
    end
  end
end # LaunchD