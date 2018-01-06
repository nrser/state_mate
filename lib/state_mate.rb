# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------
require 'set'

# Deps
# -----------------------------------------------------------------------

# Project / Package
# -----------------------------------------------------------------------
require "state_mate/version"
require "state_mate/error"
require "state_mate/adapters"
require "state_mate/state_set"


# Refinements
# =======================================================================

require 'nrser/refinements'
using NRSER


# Definitions
# =======================================================================

module StateMate
  @debug = false
  @debug_mode = 'a'

  DIRECTIVES = Set.new [
    # ensures that the key is set to the provided value
    :set,
    
    # ensures that the key is absent
    :unset,
    
    # ensures that the key is an array containing the provided items.
    # 
    # if the key is missing and `create` or `clobber` options evaluate true, it
    # will be created to have exactly the provided items. otherwise it will
    # fail.
    # 
    # if the value is not an array and `clobber` option evaluates true it will
    # be replaced with an array of exactly the provided items. otherwise it
    # will fail.
    # 
    :array_contains,
    
    # ensures that the value is an array that is missing the provided items.
    # 
    # if the current value is:
    # 
    # -   missing/nil/null:
    #     -   if the `unset_ok` option evaluates **true**:
    #         -   it will validate as a correct state and no action will be
    #             taken.
    #         -   **NOTE: this is the ONLY case where the action succeeds
    #             and the value IS NOT an array afterwards**.
    #     -   if the `unset_ok` option evaluates **false** (default):
    #         -   if the `create` or `clobber` options evaluate **true**:
    #             -   the value will be set to an empty array.
    #         -   otherwise:
    #             -   fails.
    # -   something else that's not an array:
    #     -   if the `clobber` option evaluates **true**:
    #         -   value will be set to an empty array.
    #     -   if the `clobber` option evaluates **false** (default):
    #         -   fails.
    :array_missing,
    
    # initializes a value - setting it only if it is missing/nil
    :init,
  ]
  
  
  # @api dev
  # 
  # turns debug on or off
  # 
  # @param mode [Boolean|String]
  #   if a string, enables and sets the debug file mode (use 'a' or 'w').
  #   if a boolean, sets enabled.
  # 
  def self.debug= mode
    if mode.is_a? String
      @debug_mode = mode
    end
    @debug = !!mode
  end
  
  def self.debug *messages
    return unless @debug
    
    @debug_file ||= File.open('./state_mate.debug.log', @debug_mode)
    
    messages.each_with_index do |message, index|
      if index == 0
        @debug_file.write 'DEBUG '
      end
      
      if message.is_a? String
        @debug_file.puts message
      else
        @debug_file.puts
        PP.pp(message, @debug_file)
      end
    end
  end
  
  # @api util
  # *pure*
  # 
  # casts a value to a type, or raises an error if not possible.
  # this is useful because Ansible in particular likes to pass things
  # as strings.
  # 
  # @param type_name [String] the 'name' of the type to cast to.
  # @param value the value to cast.
  # 
  def self.cast type_name, value
    case type_name
    when 'string', 'str'
      value.to_s
    when 'integer', 'int'
      case value
      when Fixnum
        value
      when true
        1
      when false
        0
      when String
        if value =~ /\A[-+]?[0-9]*\Z/
          value.to_i
        elsif value.downcase == 'true'
          1
        elsif value.downcase == 'false'
          0
        else
          raise ArgumentError.new "can't cast to integer: #{ value.inspect }"
        end
      else
        raise TypeError.new "can't cast type to integer: #{ value.inspect }"
      end
    when 'float'
      case value
      when Float
        value
      when Fixnum
        value.to_f
      when String
        if value =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
          value.to_f
        else
          raise ArgumentError.new "can't cast to float: #{ value.inspect }"
        end
      else
        raise TypeError.new "can't cast type to float: #{ value.inspect }"
      end
    when 'boolean', 'bool'
      case value
      when true, false
        value
      when 0, '0', 'False', 'false', 'FALSE'
        false
      when 1, '1', 'True', 'true', 'TRUE'
        true
      else
        raise ArgumentError.new "can't cast type to boolean: #{ value.inspect }"
      end
    else
      raise ArgumentError.new "bad type name: #{ type_name.inspect }"
    end
  end

  def self.execute spec
    StateSet.from_spec(spec).execute
  end

  def self.values_equal? current, desired, adapter
    if adapter.respond_to? :values_equal?
      adapter.values_equal? current, desired
    else
      current == desired
    end
  end

  def self.set? key, current, value, adapter, options
    values_equal? current, value, adapter
  end

  def self.set key, current, value, options
    # TODO: handle options
    value
  end

  def self.unset? key, current, value, adapter, options
    current.nil?
  end

  def self.unset key, current, value, options
    # TODO: handle options
    raise "value most be nil to unset" unless value.nil?
    nil
  end

  def self.array_contains? key, current, value, adapter, options
    current.is_a?(Array) && current.any? {|v|
      values_equal? v, value, adapter
    }
  end

  def self.array_contains key, current, value, options
    case current
    when Array
      # this is just to make the function consistent, so it doesn't add another
      # copy of value if it's there... in practice StateMate should not
      # call {.array_contains} if the value is already in the array
      # (that's what {.array_contains?} tests for)
      if current.include? value
        current
      else
        current + [value]
      end

    when nil
      # it needs to be created
      if options[:create] || options[:clobber]
        [value]
      else
        raise Error::StructureConflictError.new <<-BLOCK.unblock
          can not ensure #{ key.inspect } contains #{ value.inspect } because
          the key does not exist and options[:create] is not true.
        BLOCK
      end

    else
      # there is something there, but it's not an array. out only option
      # to achieve the declared state is to replace it with a new array
      # where value is the only element, but we don't want to do that unless
      # we've been told to clobber
      if options[:clobber]
        [value]
      else
        raise Error::StructureConflictError.new <<-BLOCK.unblock
          can not ensure #{ key.inspect } contains #{ value.inspect } because
          the value is #{ current.inspect } and options[:clobber] is not true.
        BLOCK
      end
    end # case current
  end # array_contians
  
  # @param options [Hash]
  # @option options [Boolean] :unset_ok if true, the value being unset is
  #     acceptable. many plist files will simply omit the key rather than
  #     store an empty array in the case that an array value is empty,
  #     and setting these to an empty array when all we want to do is make
  #     sure that *if it is there, it doesn't contain the value* seems
  #     pointless.
  def self.array_missing? key, current, value, adapter, options
    case current
    when nil
      if options[:unset_ok]
        true
      else
        false
      end
    when Array
      !current.any? {|v| values_equal? v, value, adapter}
    else
      false
    end
  end

  def self.array_missing key, current, value, options
    case current
    when Array
      current - [value]

    when nil
      # if we're ok with the value being unset (`nil` to us here), then
      # we're done
      if options[:unset_ok]
        nil
      else
        # there is no value, only option is to create a new empty array there
        if options[:create] || options[:clobber]
          []
        else
          raise Error::StructureConflictError.new <<-BLOCK.unblock
            can not ensure #{ key.inspect } missing #{ value.inspect } because
            the key does not exist and options[:create] is not true.
          BLOCK
        end
      end

    else
      # there is something there, but it's not an array. out only option
      # to achieve the declared state is to replace it with a new empty array
      # but we don't want to do that unless we've been told to clobber
      if options[:clobber]
        []
      else
        raise Error::StructureConflictError.new <<-BLOCK.unblock
          can not ensure #{ key.inspect } missing #{ value.inspect } because
          the value is #{ current.inspect } and options[:clobber] is not true.
        BLOCK
      end
    end # case current
  end # array_missing
  
  # the value is initialized if it's currently not nil
  def self.init? key, current, value, adapter, options
    return !current.nil?
  end
  
  # when a value needs to be initialized it is simply set to the value.
  def self.init key, current, value, options
    return value
  end

end # StateMate
