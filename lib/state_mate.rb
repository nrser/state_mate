require 'set'
require 'nrser'

require "state_mate/version"

using NRSER

module StateMate

  DIRECTIVES = Set.new [
    'set',
    'unset',
    'array_contains',
    'array_missing',
  ]

  module Error
    class ExecutionError < StandardError; end

    class WriteError < ExecutionError; end

    class ValueChangeError < ExecutionError; end

    class TypeError < ::TypeError
      attr_accessor :value

      def initialize value, msg
        @value = value
        super "#{ msg }, found #{ value.inspect }"
      end
    end
  end # Error

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
        adapter = StateMate.get_adapter adapter_name

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
          options = {}

          state.each do |k, v|
            if k == 'key'
              key = v
            elsif DIRECTIVES.include? k
              directives << [k, v]
            else
              options[k] = v
            end
          end

          directive, value = case directives.length
          when 0
            raise "no directive found in #{ key_value.inspect }"
          when 1
            directives.first
          else
            raise "multiple directives found in #{ key_value.inspect }"
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
        in_sync = test_method.call state.key, read_value, state.value

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
          raise Error::ValueChangeError.new tpl binding, <<-BLOCK
            an error occured when changing a values:

            <%= @new_value_error.format %>

            no changes were attempted to the system, so there is no rollback
            neessicary.
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
          raise Error::WriteError.new tpl binding, <<-BLOCK
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
        @changes[[state.adapter.class.name, state.key]] = new_values_hash[state]
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

  def self.get_adapter adapter_name
    # TODO: this is a punt for now, not sure how best to do registration
    case adapter_name
    when 'defaults'
      require 'state_mate/adapters/defaults'
      StateMate::Adapters::Defaults
    when 'nvram'
      require 'state_mate/adapters/nvram'
      StateMate::Adapters::NVRAM
    else
      raise "can't find adapter #{ adapter_name.inspect }"
    end
  end

  def self.execute spec
    StateSet.from_spec(spec).execute
  end

  def self.set? key, current, value
    current == value
  end

  def self.set key, current, value, options
    # TODO: handle options
    value
  end

  def self.unset? key, current, value
    current.nil?
  end

  def self.unset key, current, value, options
    # TODO: handle options
    raise "value most be nil to unset" unless value.nil?
    nil
  end

  def self.array_contains? key, current, value
    current.is_a?(Array) && current.include?(new_value)
  end

  def self.array_contains key, current, value, options
    case current
    when Array
      current + [value]

    when nil
      # it needs to be created
      if options[:create]
        [value]
      else
        raise <<-BLOCK.unblock
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
        raise <<-BLOCK.unblock
          can not ensure #{ key.inspect } contains #{ value.inspect } because
          the value is #{ current.inspect } and options[:clobber] is not true.
        BLOCK
      end
    end # case current
  end # array_contians

  def self.array_missing? key, current, value
    current.is_a?(Array) && !current.include?(value)
  end

  def self.array_missing key, current, value, options
    case current
    when Array
      current - [value]

    when nil
      # there is no value, only option is to create a new empty array there
      if options[:create]
        []
      else
        raise <<-BLOCK.unblock
          can not ensure #{ key.inspect } missing #{ value.inspect } because
          the key does not exist and options[:create] is not true.
        BLOCK
      end

    else
      # there is something there, but it's not an array. out only option
      # to achieve the declared state is to replace it with a new empty array
      # but we don't want to do that unless we've been told to clobber
      if options[:clobber]
        []
      else
        raise <<-BLOCK.unblock
          can not ensure #{ key.inspect } missing #{ value.inspect } because
          the value is #{ current.inspect } and options[:clobber] is not true.
        BLOCK
      end
    end # case current
  end # array_missing

end # StateMate
