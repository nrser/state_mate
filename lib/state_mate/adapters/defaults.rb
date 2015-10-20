require 'shellwords'
require 'rexml/document'
require 'base64'
require 'time'
require 'pp'
require 'tempfile'

require 'CFPropertyList'

require 'cmds'

require 'state_mate'

module StateMate::Adapters::Defaults
  include StateMate::Adapters
  register 'defaults'
  
  # constants
  # ========
  
  # string seperator used to split keys
  KEY_SEP = ':'
  
  # path to the `defaults` system command
  DEFAULTS_CMD = '/usr/bin/defaults'
  
  
  # adapter api methods
  # ===================
  
  # @api adapter
  # 
  # the API method that {StateMate.execute} calls (through 
  # {StateMate::StateSet#execute}) to read the value of a (possibly deep) key.
  #
  # @param key [String] a `:` seperated string who's first segment is the 
  #     domain and remaining segments are keys in presumably nested
  #     dictionaries
  #     
  #         Defaults.read "com.nrser.state_mate:x:y"
  #     
  #     would read the `com.nrser.state_mate` domain's `x` key, and, assuming
  #     it's a dictionary, get the value of it's `y` key. if the method stops
  #     finding dictionaries at any point travering the key it will return
  #     `nil`.
  # 
  # @param options [Hash]
  # @option options [Boolean] 'current_host' if true, the read will be done
  #     for the domain's "current host" plist file (using the `-currentHost`
  #     option when calling the system's `defaults` command).
  #     
  #     note that the key is a {String} and not a {Symbol}.
  # 
  # @return our Ruby representation of the value, or `nil` if it's not found.
  # 
  def self.read key, options = {}
    if options.key? :current_host
      raise ArgumentError.new NRSER.squish <<-END
        current_host option key must be a string, not a symbol.
      END
    end
    
    options = {
      'current_host' => false,
    }.merge options

    domain, key_segs = parse_key key

    value = read_defaults domain, options['current_host']

    key_segs.each do |seg|
      value = if (value.is_a?(Hash) && value.key?(seg))
        value[seg]
      else
        nil
      end
    end

    value
  end # ::read
  
  
  # @api adapter
  # 
  # the API method that {StateMate.execute} calls (through 
  # {StateMate::StateSet#execute}) to write the value of a (possibly deep) key.
  #
  # @param key [String] a `:` seperated string who's first segment is the 
  #     domain and remaining segments are keys in presumably nested
  #     dictionaries
  #     
  #         Defaults.write "com.nrser.state_mate:x", 1
  #     
  #     would write the integer `1` the `com.nrser.state_mate` domain's `x`
  #     key.
  # 
  # @param options [Hash]
  # @option options [Boolean] 'current_host' if true, the read will be done
  #     for the domain's "current host" plist file (using the `-currentHost`
  #     option when calling the system's `defaults` command).
  #     
  #     note that the key is a {String} and not a {Symbol}.
  # 
  # @return nil
  # 
  def self.write key, value, options = {}
    if options.key? :current_host
      raise ArgumentError.new NRSER.squish <<-END
        current_host option key must be a string, not a symbol.
      END
    end
    
    options = {
      'current_host' => false,
    }.merge options

    domain, key_segs = parse_key key

    if key_segs.length > 1
      deep_write  domain,
                  key_segs[0],
                  key_segs.drop(1),
                  value,
                  options['current_host']
    else
      basic_write domain,
                  key_segs[0],
                  value,
                  options['current_host']
    end
    
    nil
  end # ::write
  
  
  # util methods
  # ============
  
  # @api util
  # *pure*
  # 
  # convert a ruby object to a `REXML::Element` for a plist.
  #
  # not sure why i'm using this instead of something from {CFPropertyList}...
  # maybe it's a left-over from before {CFPropertyList} was included, maybe
  # there was some issue with {CFPropertyList}... not sure.
  #
  # @param obj [String, Fixnum, Float, Hash, Array, Boolean, Time] object to
  #     convert. Hashs and Arrays need to be composed of the same types.
  # 
  # @return [REXML::Element] the XML element representation.
  #
  # @raise [TypeError] if it can't handle the type of `obj`.
  #
  def self.to_xml_element obj
    case obj
    when String
      REXML::Element.new("string").add_text obj
    when Fixnum
      REXML::Element.new('integer').add_text obj.to_s
    when Float
      REXML::Element.new('real').add_text obj.to_s
    when Hash
      dict = REXML::Element.new('dict')
      obj.each {|dict_key, dict_obj|
        dict.add_element REXML::Element.new('key').add_text(dict_key)
        dict.add_element to_xml_element(dict_obj)
      }
      dict
    when Array
      array = REXML::Element.new('array')
      obj.each {|array_entry|
        array.add_element to_xml_element(array_entry)
      }
      array
    when TrueClass, FalseClass
      REXML::Element.new obj.to_s
    when Time
      REXML::Element.new('date').add_text obj.utc.iso8601
    else
      raise TypeError, "can't handle type: #{ obj.inspect }"
    end
  end # ::to_xml_element
  
  
  # @api util
  # *pure*
  # 
  # builds the `Preferences` folder path depending on the user given,
  # which will be either
  # 
  #     "/Library/Preferences"
  #
  # if `user` is `"root"`, otherwise
  # 
  #     "/Users/#{ user }/Library/Preferences"
  #
  # @param user [String] the user in question.
  # 
  # @return [String] the path to their `Preferences` folder.
  #
  def self.prefs_path user
    if user == 'root'
      '/Library/Preferences'
    else
      "/Users/#{ user }/Library/Preferences"
    end
  end # ::prefs_path
  
  
  # @api util
  # 
  # get the "by host" / "current host" id, also called the "hardware uuid".
  # 
  # adapted from
  # 
  # <http://stackoverflow.com/questions/933460/unique-hardware-id-in-mac-os-x>
  # 
  # @return [String] the hardware uuid
  #
  def self.hardware_uuid
    plist_xml_str = Cmds!("ioreg -r -d 1 -c IOPlatformExpertDevice -a").out
    plist = CFPropertyList::List.new data: plist_xml_str
    dict = CFPropertyList.native_types(plist.value).first
    dict['IOPlatformUUID']
  end # ::hardware_uuid
  
  
  # @api util
  # 
  # get the filepath to the `.plist` for a domain string.
  # 
  # not currently called by any StateMate stuff but seemed nice to keep
  # around for scripts and the like.
  # 
  # @param domain [Stirng] handles domains and path in the forms
  #
  #     - absolute paths (that start with `/`)
  #     - home-based paths (that start with `~`)
  #     - `"NSGlobalDomain"` for the global domain
  #     - stadard domain-style paths (`"com.nrser.state_mate"` style)
  # 
  # @param user [String] user name (`"nrser"`, `"root"`, etc.)
  # 
  # @param current_host [Boolean] whether to path to the "current host"
  #     location of a domain. onyl applicable when using global or 
  #     domain-style `domain` argument.
  #
  # @return [String] path to `.plist` file (which may not exist)
  #
  def self.domain_to_filepath domain, user = ENV['USER'], current_host = false
    # there are a few cases:
    #
    # 1.) absolute file path
    if domain.start_with? '/'
      domain
    # 
    # 2.) home-based path
    elsif domain.start_with? '~/'
      if user == 'root'
        "/var/root/#{ domain[2..-1] }"
      else
        "/Users/#{ user }/#{ domain[2..-1] }"
      end
    #
    # global domain
    elsif domain == "NSGlobalDomain"
      if current_host
        "#{ prefs_path user }/.GlobalPreferences.#{ hardware_uuid }.plist"
      else
        "#{ prefs_path user }/.GlobalPreferences.plist"
      end
    # 
    # 3.) domain with corresponding plist
    else
      if current_host
        "#{ prefs_path user }/ByHost/#{ domain }.#{ hardware_uuid }.plist"
      else
        "#{ prefs_path user }/#{ domain }.plist"
      end
    end
  end # ::domain_to_filepath
  
  
  # @api util
  # *pure*
  # 
  # parses the key into domain and key segments.
  #
  # @param key [Array<String>, String] an Array of non-empty Strings or a
  #     a String that splits by `:` into an non-empty Array of non-empty
  #     Strings.
  # 
  # @return [Array<String, Array<String>>] the String domain followed by an
  #     array of key segments.
  # 
  # @raise [ArgumentError] if the key does not parse into a non-empty list
  #     of non-empty strings.
  #
  def self.parse_key key
    strings = case key
    when Array
      key
    when String
      key.split KEY_SEP
    else
      raise "must be string or array, not #{ key.inspect }"
    end # case
    
    # make sure there is at least one element
    if strings.empty?
      raise ArgumentError.new NRSER.squish <<-END
        key parsed into empty list: #{ key.inspect }.
      END
    end
    
    # check for non-strings, empty domain or key segments
    strings.each do |string|
      if !string.is_a?(String) || string.empty?
        raise ArgumentError.new NRSER.squish <<-END
          domain and all key segments must be non-empty Strings,
          found #{ string.inspect } in key #{ key.inspect }.
        END
      end
    end

    [strings[0], strings[1..-1]]
  end # ::parse_key
  
  
  # @api util
  # *pure*
  # 
  # creates a native Ruby type represnetation of a CFType hiercharchy.
  # 
  # customized from {CFPropertyList} to use the Base64 encoding of binary
  # blobs since JSON pukes on the raw ones.
  # 
  # @param object [CFPropertyList::CFType, nil] the object to convert.
  # 
  # @param keys_as_symbols [Boolean] provide `true` to convert dictionary keys
  #     to Symbols instead of the default Strings.
  #     
  # @return native ruby object represnetation of the CFType.
  #
  def self.native_types(object,keys_as_symbols=false)
    return if object.nil?

    if (object.is_a?(CFPropertyList::CFDate) ||
        object.is_a?(CFPropertyList::CFString) || 
        object.is_a?(CFPropertyList::CFInteger) || 
        object.is_a?(CFPropertyList::CFReal) || 
        object.is_a?(CFPropertyList::CFBoolean)) || 
        object.is_a?(CFPropertyList::CFUid) then
      return object.value
    elsif(object.is_a?(CFPropertyList::CFData)) then
      return CFPropertyList::Blob.new(object.encoded_value)
    elsif(object.is_a?(CFPropertyList::CFArray)) then
      ary = []
      object.value.each do
        |v|
        ary.push native_types(v)
      end

      return ary
    elsif(object.is_a?(CFPropertyList::CFDictionary)) then
      hsh = {}
      object.value.each_pair do
        |k,v|
        k = k.to_sym if keys_as_symbols
        hsh[k] = native_types(v)
      end

      return hsh
    end
  end
  
  
  # @api util
  # 
  # does a "deep" mutating write in a Hash given a series of keys and a value.
  # 
  # @param hash [Hash] the hash to modify.
  # @param key [Array<Object>] series of keys.
  # @param value [Object] value to write.
  #
  # @return the `value`.
  # 
  def self.hash_deep_write! hash, key, value
    segment = key.first
    rest = key[1..-1]

    # terminating case: we are at the last segment
    if rest.empty?
      hash[segment] = value
    else
      case hash[segment]
      when Hash
        # go deeper
        hash_deep_write! hash[segment], rest, value
      else
        hash[segment] = {}
        hash_deep_write! hash[segment], rest, value
      end
    end
    value
  end # hash_deep_write!
  
  
  # internal methods
  # ================
  
  # @api private
  # 
  # does an system call to read and parse an domain's entire plist file using
  # `defaults export ...`.
  # 
  # @param domain [String] anything `defaults` excepts as a domain. think it
  #     can still be a filepath (they've been saying they're gonna depreciate
  #     that) or a `"com.whatever.someapp"` type string.
  # 
  # @param current_host [Boolean] whether to read the defaults for the
  #     "current host" by including the `-currentHost` flag
  #
  # @return [Hash] our Ruby representation of the underlying property list.
  # 
  # @raise [SystemCallError] if the `defaults` command fails.
  # 
  def self.read_defaults domain, current_host = false
    file = Tempfile.new('read_defaults')
    begin
      Cmds! '%{cmd} %{current_host?} export %{domain} %{filepath}',
            cmd: DEFAULTS_CMD,
            current_host: (current_host ? '-currentHost' : nil),
            domain: domain,
            filepath: file.path

      plist = CFPropertyList::List.new file: file.path
      data = native_types plist.value
    ensure
      file.close
      file.unlink   # deletes the temp file
    end
  end
  
  # @api private
  # 
  # reads the type of key using `defauls read-type ...` (hence it only
  # reads top-level keys).
  # 
  # @param domain [String] anything `defaults` excepts as a domain. think it
  #     can still be a filepath (they've been saying they're gonna depreciate
  #     that) or a `"com.whatever.someapp"` type string.
  # 
  # @param key [String] the key to read (top-level only).
  # 
  # @param current_host [Boolean] whether to read the type for the
  #     "current host" by including the `-currentHost` flag
  # 
  # @return [Symbol] one of
  #     
  #     - `:string`
  #     - `:data`
  #     - `:int`
  #     - `:float`
  #     - `:bool`
  #     - `:date`
  #     - `:array`
  #     - `:dict`
  #
  def self.read_type domain, key, current_host    
    result = Cmds!  '%{cmd} %{current_host?} read-type %{domain} %{key}',
                    cmd: DEFAULTS_CMD,
                    current_host: (current_host ? '-currentHost' : nil),
                    domain: domain,
                    key: key

    out = result.out.chomp

    case out
    when "Type is string"
      :string
    when "Type is data"
      :data
    when "Type is integer"
      :int
    when "Type is float"
      :float
    when "Type is boolean"
      :bool
    when "Type is date"
      :date
    when "Type is array"
      :array
    when "Type is dictionary"
      :dict
    else
      raise "unknown output: #{ out.inspect }"
    end
  end # ::read_type
  
  
  # @api private
  # 
  # does a delete of either a entire domain's properties or a single
  # top level key directly using `defaults delete ...`.
  #
  # called by {.basic_write} when it's provided `nil` for a value.
  # 
  # @param domain [String] that `defaults` will accept as a domain.
  # 
  # @param key [String] that `defaults` will accept as a key (top-level only).
  # 
  # @param current_host [Boolean] if true, the write will be done
  #     for the domain's "current host" plist file (using the `-currentHost`
  #     option when calling the system's `defaults` command).
  #     
  # @return nil
  #
  def self.basic_delete domain, key, current_host
    sudo = domain.start_with?('/Library') ? "sudo" : nil
    
    Cmds! '%{sudo?} %{cmd} %{current_host?} delete %{domain} %{key?}',
          cmd: DEFAULTS_CMD,
          current_host: (current_host ? '-currentHost' : nil),
          domain: domain,
          key: (key ? key : nil),
          sudo: sudo
    
    nil
  end


  # @api private
  # 
  # does a write of either a entire domain's properties or a single
  # top level key directly using `defaults write ...`.
  #
  # called by {.write} when there are zero or one key segments.
  # 
  # @param domain [String] that `defaults` will accept as a domain.
  # 
  # @param key [String] that `defaults` will accept as a key (top-level only).
  # 
  # @param value [Object] something that is acceptible to {.to_xml_element}.
  # 
  # @param current_host [Boolean] if true, the write will be done
  #     for the domain's "current host" plist file (using the `-currentHost`
  #     option when calling the system's `defaults` command).
  #     
  # @return nil
  #
  def self.basic_write domain, key, value, current_host
    if value.nil?
      basic_delete(domain, key, current_host)
    else
      sudo = domain.start_with?('/Library') ? "sudo" : nil
      
      Cmds! '%{sudo?} %{cmd} %{current_host?} write %{domain} %{key?} %{xml}',
            cmd: DEFAULTS_CMD,
            current_host: (current_host ? '-currentHost' : nil),
            domain: domain,
            key: (key ? key : nil),
            xml: to_xml_element(value).to_s,
            sudo: sudo
    end
    
    nil
  end # ::basic_write
  
  
  # @api private
  # 
  # internal compliment to {.basic_write} that writes "deep" keys (keys with
  # additional segments beyond domain and top-level).
  #
  # @param domain [String] domain string that `defaults` will accept.
  # 
  # @param key [String] key string that `defaults` will accept.
  # 
  # @param deep_segs [Array<String>] non-empty strings that form the "deep"
  #     part of the key.
  # 
  # @param value [Object] something that is acceptible to {.to_xml_element}.
  # 
  # @param current_host [Boolean] if true, the write will be done
  #     for the domain's "current host" plist file (using the `-currentHost`
  #     option when calling the system's `defaults` command).
  #     
  # @return nil
  # 
  def self.deep_write domain, key, deep_segs, value, current_host
    root = read [domain, key], 'current_host' => current_host
    # handle the root not being there
    root = {} unless root.is_a? Hash
    hash_deep_write! root, deep_segs, value
    basic_write domain, key, root, current_host
    nil
  end # ::deep_write
end
