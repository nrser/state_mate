require 'yaml'
require 'diffable_yaml'

require 'state_mate'
require 'state_mate/adapters/defaults'

module StateMate::Adapters::YAML
  include StateMate::Adapters
  register 'yaml'
  
  @preorder = []
  
  def self.preorder= keys
    @preorder = keys
  end
  
  def self.parse_key key
    # use the same key seperation as Defaults
    StateMate::Adapters::Defaults.parse_key key
  end
  
  def self.cast_seg key_seg
    if key_seg =~ /\A[0-9]+\z/
      key_seg.to_i
    else
      key_seg
    end
  end

  def self.read key, options = {}
    filepath, key_segs = parse_key key

    contents = File.read(File.expand_path(filepath))

    value = ::YAML.load contents

    key_segs.each do |seg|
      seg = cast_seg seg
      
      value = case value
      when Hash, Array
        value = value[seg]
      else
        nil
      end
    end

    value
  end
  
  def self.write key, value, options = {}
    StateMate.debug key: key, value: value, options: options
    
    filepath, key_segs = parse_key key

    new_root = if key_segs.length > 1
      root = read filepath

      deep_write! root, key_segs, value

      root
    else
      value
    end

    content = DiffableYAML.dump new_root, preorder: @preorder

    File.open(filepath, 'w') do |f|
      f.write content
    end
  end
  
  def self.deep_write! obj, key_segs, value
    seg = cast_seg key_segs.first
    rest = key_segs[1..-1]
    
    if rest.empty?
      obj[seg] = value
      
    else
      deep_write! obj[seg], rest, value
      
    end
  end
end # YAML
