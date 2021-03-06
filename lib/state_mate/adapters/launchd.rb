require 'pp'

require 'CFPropertyList'

require 'nrser'

require 'state_mate'
require 'state_mate/adapters/defaults'

using NRSER

# very useful:
# 
# <http://launchd.info/>
# 46

module StateMate::Adapters::LaunchD
  include StateMate::Adapters
  register 'launchd'

  EXE = '/bin/launchctl'

  def self.truncate_values hash, length
    hash.map {|k, v|
      case v
      when String
        [k, v.truncate(length)]
      when Hash
        [k, truncate_values(v, length)]
      else
        [k ,v]
      end
    }.to_h
  end

  def self.user_overrides_db_path user = ENV['USER']
    if user == 'root'
      "/var/db/launchd.db/com.apple.launchd/overrides.plist"
    else
      user_id = Cmds!("id -u %{user}", user: user).out.chomp.to_i
      "/var/db/launchd.db/com.apple.launchd.peruser.#{ user_id }/overrides.plist"
    end
  end

  def self.user_overrides_db user = ENV['USER']
    plist = CFPropertyList::List.new file: user_overrides_db_path(user)
    CFPropertyList.native_types plist.value
  end

  def self.disabled? label, user = ENV['USER']
    db = user_overrides_db(user)
    return false unless db.key?(label) && db[label].key?('Disabled')
    db[label]['Disabled']
  end

  def self.loaded? label
      Cmds.ok? "%{exe} list -x %{label}", exe: EXE, label: label
  end

  def self.parse_key key
    # use the same key seperation as Defaults
    StateMate::Adapters::Defaults.parse_key key
  end

  def self.load file_path
    Cmds! "%{exe} load -w %{file_path}",  exe: EXE,
                                          file_path: file_path
  end

  def self.unload file_path
    Cmds! "%{exe} unload -w %{file_path}",  exe: EXE,
                                            file_path: file_path
  end

  def self.read key, options = {}
    file_path, key_segs = parse_key key

    # get the hash of the plist at the file path and use that to get the label
    plist = CFPropertyList::List.new file: file_path
    data = CFPropertyList.native_types plist.value
    label = data["Label"]

    case key_segs
    # the only thing we can handle right now
    when ['Disabled']
      disabled? label
    else
      raise "unprocessable key: #{ key.inspect }"
    end
  end

  def self.write key, value, options = {}
    file_path, key_segs = parse_key key

    case key_segs
    when ['Disabled']
      case value
      when true
        unload file_path

      when false
        load file_path

      else
        raise StateMate::Error::TypeError value, "expected true or false"

      end
    else
      raise "unprocessable key: #{ key.inspect }"
    end
  end
end # LaunchD
