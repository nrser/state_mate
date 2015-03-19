require 'shellwords'
require 'rexml/document'
require 'base64'
require 'time'
require 'nrser'

using NRSER

module StateMate; end
module StateMate::Adapters; end

module StateMate::Adapters::Defaults
  KEY_SEP = ':'
  DEFAULTS_CMD = '/usr/bin/defaults'
  PLISTBUDDY_CMD = '/usr/libexec/PlistBuddy'

  # substitute stuff into a shell command after escaping with 
  # `Shellwords.escape`.
  #
  # arguments after the first may be multiple values that will
  # be treated like a positional list for substitution, or a single
  # hash that will be treated like a key substitution.
  #
  # any substitution value that is an Array will be treated like a list of
  # path segments and joined with `File.join`.
  def self.sub command, subs
    quoted = case subs
    when Hash
      Hash[
        subs.map do |key, sub|
          sub = File.join(*sub) if sub.is_a? Array
          # shellwords in 1.9.3 can't handle symbols
          sub = sub.to_s if sub.is_a? Symbol
          [key, Shellwords.escape(sub)]
        end
      ]
    when Array
      subs.map do |sub|
        sub = File.join(*sub) if sub.is_a? Array
        # shellwords in 1.9.3 can't handle symbols
        sub = sub.to_s if sub.is_a? Symbol
        Shellwords.escape sub
      end
    else
      raise "should be Hash or Array: #{ subs.inspect }"
    end
    command % quoted
  end # ::sub

  def self.exec cmd
    output = `#{ cmd } 2>&1`
    exitstatus = $?.exitstatus

    if exitstatus == 0
      return output
    else
      raise SystemCallError.new <<-BLOCK.unblock, exitstatus
        hey - cmd `#{ cmd }` failed with status #{ $?.exitstatus }
        and output #{ output.inspect }
      BLOCK
    end
  end # ::exec

  def self.read_cmd filepath, key
    sub(
      '%{cmd} -x -c %{print} %{filepath}', 
      cmd: PLISTBUDDY_CMD,
      print: "Print '#{ KEY_SEP }#{ key.join(KEY_SEP) }'",
      filepath: filepath
    )
  end # ::read_cmd


  def self.write_cmd filepath, key, xml
    sub(
      "%{cmd} write %{filepath} %{key} %{xml}",
      cmd: DEFAULTS_CMD,
      filepath: filepath,
      key: key.join(KEY_SEP),
      xml: xml
    )
  end # ::write_cmd

  def self.to_ruby_obj elem
    case elem.name
    when 'string'
      elem.text
    when 'integer'
      elem.text.to_i
    when 'real'
      elem.text.to_f
    when 'array'
      elem.elements.map {|array_elem|
        to_ruby_obj array_elem
      }
    when 'dict'
      elem.elements.each_slice(2).map {|key_elem, value_elem|
        [key_elem.text, to_ruby_obj(value_elem)]
      }.pipe {|array|
        Hash[array]
      }
    when 'true'
      true
    when 'false'
      false
    when 'date'
      # ISO 8601
      Time.parse elem.text
    when 'data'
      Base64.decode64 elem.text
    else
      raise "can't process element: #{ elem.inspect }"
    end
  end # ::to_ruby_obj

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

  def self.domain_to_filepath domain, user = ENV['USER']
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
      "#{ prefs_path user }/.GlobalPreferences.plist"
    # 
    # 3.) domain with corresponding plist
    else
      "#{ prefs_path user }/#{ domain }.plist"
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

  def self.read key, options = {}
    domain, key_segs = parse_key key
    filepath = domain_to_filepath domain

    read_cmd = read_cmd filepath, key_segs

    begin
      str = exec read_cmd
    rescue SystemCallError => e
      return nil
    end

    doc = REXML::Document.new(str)
    to_ruby_obj doc.elements.first.elements.first
  end # ::read

  def self.write key, value, options = {}
    domain, key_segs = parse_key key
    filepath = domain_to_filepath domain
    xml = to_xml_element(value).to_s

    write_cmd = write_cmd filepath, key_segs, xml
    exec write_cmd
  end # ::write
end
