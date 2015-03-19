require 'nrser'
require 'nrser/exec'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::NVRAM
  def self.read key, options = {}
    cmd = NRSER::Exec.sub "nvram %{key}", key: key

    begin
      output = NRSER::Exec.run cmd
    rescue SystemCallError => e
      if e.message.include? "nvram: Error getting variable"
        return nil
      else
        raise e
      end
    end

    if m = /^#{ key }\t(.*)\n$/.match(output)
      m[1]
    else
      raise tpl binding, <<-BLOCK
        can't parse output for key <%= key.inspect %>:

          cmd: <%= cmd.inspect %>

          output: <%= output.inspect %>
      BLOCK
    end
  end

  def self.write key, value, options = {}
    unless value.is_a? String 
      raise "value must be a String, not #{ value.inspect }"
    end

    cmd = "nvram #{ key }='#{ value }'"
    NRSER::Exec.run cmd
  end
end # NVRAM