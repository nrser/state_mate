require 'pp'

module StateMate; end

module StateMate::Adapters
  API_METHOD_NAMES = [:read, :write]
  
  @@index = {}
  
  module IncludeClassMethods
    def register name
      StateMate::Adapters.register name, self
    end
  end
  
  def self.included base
    base.extend IncludeClassMethods
  end
  
  def self.register name, obj
    unless name.is_a? String
      raise StateMate::Error::TypeError.new name, "name must be a String"
    end
    
    @@index[name] = obj
  end
  
  def self.get name
    # return it if it's already loaded
    return @@index[name] if @@index.key? name
    
    # try to require it
    begin
      require "state_mate/adapters/#{ name }"
    rescue LoadError => e
    end
    
    unless @@index.key? name
      raise StateMate::Error::AdapterNotFoundError.new NRSER.dedent <<-END
        adapter #{ name.inspect } was not found.
        
        registered adapters:
        
        #{ @@index.pretty_inspect }
        
      END
    end
    
    @@index[name]
  end
  
end # Adapters