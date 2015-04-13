require 'shellwords'
require 'rexml/document'
require 'base64'
require 'time'
require 'pp'
require 'tempfile'

require 'CFPropertyList'

require 'nrser'
require 'nrser/exec'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::Defaults
  KEY_SEP = ':'
  DEFAULTS_CMD = '/usr/bin/defaults'

  # convert a ruby object to a `REXML::Element` for a plist
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
      raise "can't handle type: #{ obj.inspect }"
    end
  end # ::to_xml_element

  def self.prefs_path user
    if user == 'root'
      '/Library/Preferences'
    else
      "/Users/#{ user }/Library/Preferences"
    end
  end # ::prefs_path

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

  def self.parse_key key
    domain, *key_segs = case key
    when Array
      key
    when String
      key.split KEY_SEP
    else
      raise "must be string or array, not #{ key.inspect }"
    end # case
    [domain, key_segs]
  end # ::parse_key

  # Converts a CFType hiercharchy to native Ruby types
  # 
  # customized to use the Base64 encoding of binary blobs since
  # JSON pukes on the raw ones
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

  def self.read_defaults domain, current_host = false
    file = Tempfile.new('read_defaults')
    begin
      cmd_parts = ['%{cmd}']
      cmd_parts << '-currentHost' if current_host
      cmd_parts << 'export'
      cmd_parts << '%{domain}'
      cmd_parts << '%{filepath}'
      cmd = NRSER::Exec.sub cmd_parts.join(' '),  cmd: DEFAULTS_CMD,
                                                  domain: domain,
                                                  filepath: file.path
      NRSER::Exec.run cmd

      plist = CFPropertyList::List.new file: file.path
      data = native_types plist.value
    ensure
      file.close
      file.unlink   # deletes the temp file
    end
  end

  def self.read_type domain, key, current_host
    cmd_parts = ['%{cmd}']
    cmd_parts << '-currentHost' if current_host
    cmd_parts << 'read-type'
    cmd_parts << '%{domain}'
    cmd_parts << '%{key}'

    cmd = NRSER::Exec.sub cmd_parts.join(' '),  cmd: DEFAULTS_CMD,
                                                domain: domain,
                                                key:    key

    out = NRSER::Exec.run(cmd).chomp

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

  def self.read key, options = {}
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

    # when 0 or 1 are returned they might actually be true or false
    # case value
    # when 0, 1
    value
  end # ::read

  # def self.read_type

  def self.write key, value, options = {}
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
  end # ::write

  def self.basic_delete domain, key, current_host
    cmd_parts = ['%{cmd}']
    cmd_parts << '-currentHost' if current_host
    cmd_parts << 'delete'
    cmd_parts << '%{domain}'
    cmd_parts << '%{key}' unless key.empty?

    result = NRSER::Exec.result cmd_parts.join(' '),  cmd: DEFAULTS_CMD,
                                                      domain: domain,
                                                      key: key

    result.check_error
    result
  end

  def self.basic_write domain, key, value, current_host
    return basic_delete(domain, key, current_host) if value.nil?

    xml = to_xml_element(value).to_s

    cmd_parts = ['%{cmd}']
    cmd_parts << '-currentHost' if current_host
    cmd_parts << 'write'
    cmd_parts << '%{domain}'
    cmd_parts << '%{key}' unless key.empty?
    cmd_parts << '%{xml}'

    cmd = NRSER::Exec.sub cmd_parts.join(' '),  cmd:    DEFAULTS_CMD,
                                                domain: domain,
                                                key:    key,
                                                xml:    xml

    NRSER::Exec.run cmd
  end # ::basic_write

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

  def self.deep_write domain, key, deep_segs, value, current_host
    root = read [domain, key], current_host: current_host
    # handle the root not being there
    root = {} if root.nil?
    hash_deep_write! root, deep_segs, value
    basic_write domain, key, root, current_host
  end # ::deep_write

  # get the "by host" / "current host" id, also called the "hardware uuid".
  # adapted from
  # 
  # <http://stackoverflow.com/questions/933460/unique-hardware-id-in-mac-os-x>
  # 
  def self.hardware_uuid
    plist_xml_str = NRSER::Exec.run "ioreg -r -d 1 -c IOPlatformExpertDevice -a"
    plist = CFPropertyList::List.new data: plist_xml_str
    dict = CFPropertyList.native_types(plist.value).first
    dict['IOPlatformUUID']
  end # ::hardware_uuid

  # `defaults` will return `true` as `1` and `false` as `0` :/
  def self.values_equal? current, desired
    case desired
    when true
      current == true || current == 1
    when false
      current == false || current == 0
    else
      current == desired
    end
  end
end
