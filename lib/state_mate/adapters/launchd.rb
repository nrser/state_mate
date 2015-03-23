require 'pp'

require 'nrser'
require 'nrser/exec'

require 'state_mate'
require 'state_mate/adapters/defaults'

using NRSER

# very useful:
# 
# <http://launchd.info/>
# 46

module StateMate::Adapters::LaunchD

  EXE = '/bin/launchctl'

  def self.truncate_values hash, length
    hash.map {|k, v|
      case v
      when String
        [k, v.truncate(length)]
      when Hash
        [k, truncate_strings(v, length)]
      else
        [k ,v]
      end
    }.to_h
  end

  def self.user_overrides_db_path user = ENV['USER']
    user_id = NRSER::Exec.run("id -u %{user}", user: user).chomp.to_i
    "/var/db/launchd.db/com.apple.launchd.peruser.#{ user_id }/overrides.plist"
  end

  def self.user_overrides_db user = ENV['USER']
    StateMate::Adapters::Defaults.read user_overrides_db_path(user)
  end

  def self.disabled? label, user = ENV['USER']
    db = user_overrides_db(user)
    # TODO: not sure how to handle the value not being present
    unless db.key? label
      raise tpl binding, <<-BLOCK
        label <%= label.inspect %> not found in launchd user overrides db:

        <%= truncate_values(db, 48).pretty_inspect.indent %>
        BLOCK
    end
    unless db[label].key? 'Disabled'
      raise tpl binding, <<-BLOCK
        entry for label <%= label %> in launchd user overrides db does not
        have a 'Disabled' value:

        <%= truncate_values(db[label], 48).pretty_inspect.indent %>
      BLOCK
    end
    db[label]['Disabled']
  end

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