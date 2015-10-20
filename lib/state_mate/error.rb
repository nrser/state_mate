module StateMate
  module Error
    class StateMateError < StandardError; end
    
    class ExecutionError < StateMateError; end

    class WriteError < ExecutionError; end

    class ValueChangeError < ExecutionError; end

    class TypeError < ::TypeError
      attr_accessor :value

      def initialize value, msg
        @value = value
        super "#{ msg }, found #{ value.inspect }"
      end
    end
    
    class AdapterNotFoundError < StateMateError; end
  end # Error
end # StateMate