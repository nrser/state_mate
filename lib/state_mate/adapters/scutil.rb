require 'cmds'

module StateMate; end
module StateMate::Adapters; end

# adapter to set global git config options
module StateMate::Adapters::SCUtil

  # @api adapter
  #
  # adapter API call that reads a value from scutil.
  #
  # @param key [String] the key to read
  # @param options [Hash] unused options to conform to adapter API
  #
  # @return [String] the scutil value.
  #
  # @raise [SystemCallError] if the command failed.
  #
  def self.read key, options = {}
    Cmds.chomp! "scutil --get %{key}", key: key
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
