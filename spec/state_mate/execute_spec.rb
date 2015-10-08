require 'spec_helper'

require 'state_mate'

describe "StateMate::execute" do
  context "defaults" do
    include_context "#{ DOMAIN } empty"
    
    it "writes a basic value" do
      StateMate.execute({
        'defaults' => {
          'key' => [DOMAIN, 'x'],
          'set' => 'ex',
        },
      })

      expect_defaults_read 'x', eq('ex'), 'string'
    end
  end # context defaults
    
  context "write failure" do
    include_context "#{ DOMAIN } empty"
    
    it "raises StateMate::Error::WriteError" do
      allow(StateMate::Adapters::Defaults).to receive(:write) do
        raise MockError.new
      end
      
      expect {
        StateMate.execute({
          'defaults' => {
            'key' => [DOMAIN, 'x'],
            'set' => 'ex',
          },
        })
      }.to raise_error StateMate::Error::WriteError

    end # it raises StateMate::Error::WriteError
  end # context write failure
end
