require 'nrser'
require 'nrser/exec'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::NVRAM
  def self.read key, options = {}
    result = Cmds "nvram %{key}", key: key

    if result.error?
      if result.err.start_with? "nvram: Error getting variable"
        return nil
      end
      result.assert
    end

    if m = /^#{ key }\t(.*)\n$/.match(result.out)
      m[1]
    else
      raise binding.erb <<-BLOCK
        can't parse output for key <%= key.inspect %>:

          cmd: <%= result.cmd %>

          output: <%= result.out.inspect %>
      BLOCK
    end
  end

  def self.write key, value, options = {}
    unless value.is_a? String
      raise "value must be a String, not #{ value.inspect }"
    end

    Cmds! "sudo nvram #{ key }='#{ value }'"
  end
end # NVRAM
