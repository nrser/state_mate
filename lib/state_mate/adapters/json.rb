require 'json'

require 'state_mate'
require 'state_mate/adapters/defaults'

module StateMate::Adapters::JSON
  include StateMate::Adapters
  register 'json'
  
  def self.parse_key key
    # use the same key separation as Defaults
    StateMate::Adapters::Defaults.parse_key key
  end

  def self.read key, options = {}
    filepath, key_segs = parse_key key

    contents = File.read(File.expand_path(filepath))

    value = ::JSON.load contents

    key_segs.each do |seg|
      value = if (value.is_a?(Hash) && value.key?(seg))
        value[seg]
      else
        nil
      end
    end

    value
  end

  def self.write key, value, options = {}
    options = {
      'pretty' => true,
    }.merge options

    filepath, key_segs = parse_key key
    
    StateMate.debug "writing json",
      options: options,
      filepath: filepath,
      key_segs: key_segs

    new_root = if key_segs.empty?
      value
    else
      root = read filepath

      StateMate::Adapters::Defaults.hash_deep_write!(
        root,
        key_segs,
        value
      )

      root
    end
    
    StateMate.debug new_root: new_root

    content = if options['pretty']
      ::JSON.pretty_generate new_root
    else
      ::JSON.dump new_root
    end

    File.open(filepath, 'w') do |f|
      f.write content
    end
  end
end # JSON
