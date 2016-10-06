require 'set'
require 'nrser'
require 'nrser/refinements'

using NRSER

require "state_mate/version"
require "state_mate/error"
require "state_mate/adapters"

module StateMate
  @debug = false
  @debug_mode = 'a'

  DIRECTIVES = Set.new [
    :set,
    :unset,
    :array_contains,
    :array_missing,
  ]

  class StateSet
    attr_accessor :spec
    attr_reader :states,
                :read_values,
                :states_to_change,
                :new_values,
                :written_states,
                :write_error,
                :rollback_errors,
                :changes


    State = Struct.new  :adapter,
                        :key,
                        :directive,
                        :value,
                        :options

    def self.from_spec spec
      state_set = self.new
      state_set.spec = spec

      unless spec.is_a? Hash
        raise Error::TypeError.new spec, 
          "spec must be a Hash of adapter names to states"
      end

      spec.each do |adapter_name, states|
        adapter = StateMate::Adapters.get adapter_name

        states = case states
        when Hash
          [states]
        when Array
          states
        else
          raise Error::TypeError.new states, <<-BLOCK.unblock
            each value of the spec needs to be a single state hash or an
            array or state
          BLOCK
        end

        states.each do |state|
          unless spec.is_a? Hash
            raise Error::TypeError.new state, "each state needs to be a Hash"
          end

          key = nil
          directives = []
          type_name = nil
          unset_when_false = false
          
          # the :unset_when option can be provided to change the directive to
          # :unset when the option's value is true.
          # 
          # this is useful for things that should simply unset the key when
          # turned off instead of setting it to false or something.
          # 
          unset_when = nil
          
          options = state['options'] || {}
          
          unless options.is_a? Hash
            raise TypeError.new binding.erb <<-END
              options must be a hash, found <%= options.class %>:
              
              <%= options.inspect %>
              
              state:
              
              <%= state.inspect %>
              
            END
          end
          
          state.each do |k, v|
            # normalize to symbols
            k = k.to_sym if k.is_a? String
            
            if k == :key
              key = v
            elsif k == :options
              # pass, dealt with above
            elsif DIRECTIVES.include? k
              directives << [k, v]
            elsif k == :type
              type_name = v
            elsif k == :unset_when_false
              unset_when_false = v
            elsif k == :unset_when
              unset_when = StateMate.cast 'bool', v
            else
              # any other keys are set as options
              # this is a little convience feature that avoids having to
              # nest inside an `options` key unless your option conflicts
              # with 'key' or a directive.
              #
              # check for conflicts
              if options.key? k
                raise ArgumentError.new binding.erb <<-END
                  top-level state key #{ k.inspect } was also provided in the
                  options.
                  
                  state:
                  
                  <%= state.inspect %>
                  
                END
              end
              
              options[k] = v
            end
          end

          directive, value = case directives.length
          when 0
            raise "no directive found in #{ state.inspect }"
          when 1
            directives.first
          else
            raise "multiple directives found in #{ state.inspect }"
          end
          
          # handle :unset_when_false option, which changes the operation to
          # an unset when the *directive value* is explicity false
          if  unset_when_false && 
              (value === false || ['False', 'false'].include?(value))
            directive = :unset
            value = nil
          
          # handle :unset_when, which also changes the operation to :unset
          # when the option's value is true.
          elsif unset_when
            directive = :unset
            value = nil
            
          elsif type_name
            value = StateMate.cast type_name, value
          end

          state_set.add adapter, key, directive, value, options
        end # state.each
      end # states.each

      state_set
    end # from_spec

    def initialize
      @spec = nil
      @states = []
      @read_values = {}
      @states_to_change = []
      @new_values = []
      @written_states = []
      @write_error = nil
      # map of states to errors raised when trying to rollback
      @rollback_errors = {}
      # report of changes made
      @changes = {}
    end

    def add adapter, key, directive, value, options = {}
      @states << State.new(adapter, key, directive, value, options)
    end

    def execute
      # find out what needs to be changed
      @states.each do |state|
        # read the current value
        read_value = state.adapter.read state.key, state.options

        # store it for use in the actual change
        @read_values[state] = read_value

        # the test method is the directive with a '?' appended,
        # like `set?` or `array_contains?`
        test_method = StateMate.method "#{ state.directive }?"

        # find out if the state is in sync
        in_sync = test_method.call  state.key,
                                    read_value,
                                    state.value,
                                    state.adapter,
                                    state.options

        # add to the list of changes to be made for states that are
        # out of sync
        @states_to_change << state unless in_sync
      end

      # if everything is in sync, no changes need to be attempted
      # reutrn the empty hash of changes
      return @changes if @states_to_change.empty?

      # do the change to each in-memory value
      # this will raise an excption if the operation can't be done for
      # some reason
      states_to_change.each do |state|
        sync_method = StateMate.method state.directive
        # we want to catch any error and report it
        begin
          new_value = sync_method.call  state.key,
                                        @read_values[state],
                                        state.value,
                                        state.options
        rescue Exception => e
          @new_value_error = e
          raise Error::ValueSyncError.new binding.erb <<-BLOCK
            an error occured when changing a values:

            <%= @new_value_error.format %>

            no changes were attempted to the system, so there is no rollback
            necessary.
          BLOCK
        end
        # change successful, store the new value along-side the state
        # for use in the next block
        @new_values << [state, new_value]
      end

      new_values.each do |state, new_value|
        begin
          state.adapter.write state.key, new_value, state.options
        rescue Exception => e
          @write_error = e
          rollback
          raise Error::WriteError.new binding.erb <<-BLOCK
            an error occured when writing new state values:

            <%= @write_error.format %>

            <% if @written_states.empty? %>
              the error occured on the first write, so no values were rolled
              back.

            <% else %>
              <% if @rollback_errors.empty? %>
                all values were sucessfully rolled back:

              <% else %>
                some values failed to rollback:

              <% end %>

              <% @written_states.each do |state| %>
                <% if @rollback_errors[state] %>
                  <% state.key %>: <% @rollback_errors[state].format.indent(8) %>
                <% else %> 
                  <%= state.key %>: rolled back.
                <% end %>
              <% end %>
            <% end %>
            BLOCK
        else
          @written_states << state
        end # begin / rescue / else
      end # new_values.each

      # ok, we made it. report the changes
      new_values_hash = Hash[@new_values]
      @written_states.each do |state|
        @changes[[state.adapter.name, state.key]] = [@read_values[state], new_values_hash[state]]
      end
      
      @changes
    end # execute

    private

    def rollback
      # go through the writes that were sucessfully made and try to
      # reverse them
      @written_states.reverse.each do |state|
        # wrap in rescue so that we can record that the rollback failed
        # for a value and continue
        begin
          state.adapter.write state.key, state.value, state.options
        rescue Exception => e
          # record when and why a rollback fails to include it in the
          # exiting exception
          @rollback_errors[state] = e
        end
      end
    end # rollback
  end # StateSet
  
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
  # this is useful because ansible in particular likes to pass things
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
      # call {.array_contains} if the value is alreay in the array
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
  #     acceptible. many plist files will simply omit the key rather than
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

end # StateMate
