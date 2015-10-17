require 'cmds'

module StateMate; end
module StateMate::Adapters; end

# adapter to set global git config options
module StateMate::Adapters::SCUtil

  # @api adapter
  #
  # adapter API call that reads a value from scutil.
  #
  # @param key [String] the key to read. from `man scutil`:
  #     
  #     Supported preferences include:
  #     
  #           ComputerName   The user-friendly name for the system.
  # 
  #           LocalHostName  The local (Bonjour) host name.
  # 
  #           HostName       The name associated with hostname(1) and gethostname(3).
  # 
  # @param options [Hash] unused options to conform to adapter API
  #
  # @return [String, nil] the scutil value, or `nil` if not set.
  #
  # @raise [SystemCallError] if the command failed.
  #
  def self.read key, options = {}
    result = Cmds "scutil --get %{key}", key: key
    if result.ok?
      result.out.chomp
    else
      if result.err.match /^#{ key }\:\ not set/
        nil
      else
        result.assert
      end
    end
  end # ::read


  # @api adapter
  #
  # adapter API call that writes a value to the git global config.
  #
  # @param key [String] the key to write
  # @param value [String] the value to write
  # @param options [Hash] unused options to conform to adapter API
  #
  # @return nil
  #
  def self.write key, value, options = {}
    Cmds! "sudo scutil --set %{key} %{value}",
          key: key,
          value: value
    nil
  end # ::write
end # SCUtil
