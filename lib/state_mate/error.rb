module StateMate
  module Error
    class StateMateError < StandardError; end
    
    class ExecutionError < StateMateError; end

    class WriteError < ExecutionError; end
    
    # raised when an erros is encountered running a sync method on an adapter
    #(set, unset, array_contains, array_missing)
    class ValueSyncError < ExecutionError; end

    class TypeError < ::TypeError
      attr_accessor :value

      def initialize value, msg
        @value = value
        super "#{ msg }, found #{ value.inspect }"
      end
    end
    
    class AdapterNotFoundError < StateMateError; end
    
    # raised when the current structre of a value prevents the desired sync
    # operation with the given options.
    class StructureConflictError < StateMateError; end
  end # Error
end # StateMate