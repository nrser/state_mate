# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------

# Deps
# -----------------------------------------------------------------------

# Project / Package
# -----------------------------------------------------------------------


# Refinements
# =======================================================================

require 'nrser/refinements'
using NRSER


# Declarations
# =======================================================================

module StateMate; end


# Definitions
# =======================================================================

class StateMate::StateSet
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
      raise StateMate::Error::TypeError.new spec,
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
        raise StateMate::Error::TypeError.new states, <<-BLOCK.unblock
          each value of the spec needs to be a single state hash or an
          array or state
        BLOCK
      end

      states.each do |state|
        unless spec.is_a? Hash
          raise StateMate::Error::TypeError.new state,
            "each state needs to be a Hash"
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
          elsif StateMate::DIRECTIVES.include? k
            directives << [k, v]
          elsif k == :type
            type_name = v
          elsif k == :unset_when_false
            unset_when_false = v
          elsif k == :unset_when
            unset_when = StateMate.cast 'bool', v
          else
            # any other keys are set as options
            # this is a little convenience feature that avoids having to
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
        # an unset when the *directive value* is explicitly false
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
        raise StateMate::Error::ValueSyncError.new binding.erb <<-BLOCK
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
        raise StateMate::Error::WriteError.new binding.erb <<-BLOCK
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
    # go through the writes that were successfully made and try to
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
end # class StateMate::StateSet
