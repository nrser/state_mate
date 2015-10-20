require 'cmds'

require 'state_mate'

# adapter to set global git config options
module StateMate::Adapters::GitConfig
  include StateMate::Adapters
  register 'git_config'
  
  # @api adapter
  # 
  # adapter API call that reads a value from the git global config.
  # 
  # @param key [String] the key to read
  # @param options [Hash] unused options to conform to adapter API
  # 
  # @return [String, nil] the git config value, or nil if it's missing.
  # 
  # @raise [SystemCallError] if the key is bad or something else caused the
  #     command to fail.
  def self.read key, options = {}
    result = Cmds "git config --global --get %{key}", key: key
    
    # if the command succeeded the result is the output
    # (minus trailing newline)
    if result.ok?
      result.out.chomp
    
    # if it errored with no output then the key is missing
    elsif result.err == ''
      nil
    
    # otherwise, raise an error
    else
      result.assert
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
    # decide to add or replace based on if the key has a value
    action = read(key, options).nil? ? '--add' : '--replace'

    result = Cmds!  "git config --global #{ action } %{key} %{value}",
                    key: key,
                    value: value
    
    nil
  end # ::write
end # GitConfig
