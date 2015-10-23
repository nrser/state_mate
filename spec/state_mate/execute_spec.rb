require 'spec_helper'

class TestAdapter
  attr_reader :read_value,
              :read_key,
              :read_options,
              :write_key,
              :write_value,
              :write_options
  
  def name
    "test_adapter_#{ object_id }"
  end
  
  def initialize read_value
    @read_value = read_value
    StateMate::Adapters.register name, self
  end
  
  def read key, options = {}
    @read_key = key
    @read_options = options
    @read_value
  end
  
  def write key, value, options = {}
    @write_key = key
    @write_value = value
    @write_options = options
  end
end

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
  
  context "unset_when_false" do
    include_context "#{ DOMAIN } empty"
    
    let(:adapter) { TestAdapter.new nil }
    let(:key){ 'k' }
    let(:spec) {
      {
        adapter.name => {
          key: key,
        }
      }
    }
    
    it "sets the value when it's not false" do
      value = 3.14
      spec[adapter.name][:set] = value
      spec[adapter.name][:unset_when_false] = true
      
      StateMate.execute spec
      
      expect( adapter.write_value ).to eq value
    end
    
    it "unsets the value when it is false" do
      value = false
      spec[adapter.name][:set] = value
      spec[adapter.name][:unset_when_false] = true
      
      StateMate.execute spec
      
      expect( adapter.write_value ).to eq nil
    end
    
    it "unsets the value when it is 'false'" do
      value = 'false'
      spec[adapter.name][:set] = value
      spec[adapter.name][:unset_when_false] = true
      
      StateMate.execute spec
      
      expect( adapter.write_value ).to eq nil
    end
  end
  
  # NOTE this got moved to array_contains_spec but leaving here for now for ref
  context "modifying arrays" do
    context "current value is nil" do
      # a test adapter that always reads the value as `nil`
      let(:adapter) { TestAdapter.new nil }
      let(:key){ 'k' }
      let(:value){ 'v' }
      
      it "errors when create is not provided" do
        expect {
          StateMate.execute({
            adapter.name => {
              'key' => key,
              'array_contains' => value,
            },
          })
        }.to raise_error StateMate::Error::ValueSyncError
      end
      
      it "errors when create is false" do
        expect {
          StateMate.execute({
            adapter.name => {
              'key' => key,
              'array_contains' => value,
              'create' => false,
            },
          })
        }.to raise_error StateMate::Error::ValueSyncError
      end
            
      it "creates an array when 'create' option is true" do
        StateMate.execute({
          adapter.name => {
            'key' => key,
            'array_contains' => value,
            'create' => true,
          }
        })
        
        expect(adapter.write_value).to eq [value]
      end
      
      
    end # current value is nil
  end # modifying arrays
end
