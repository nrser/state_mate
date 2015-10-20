require 'spec_helper'

describe 'StateMate::Adapters.get' do
  include_context 'adapters'
  
  it "should error when the adapter is not found" do
    expect {
      adapters.get 'MISSING'
    }.to raise_error StateMate::Error::AdapterNotFoundError
  end
  
  it "should return the adapter if it's in the adapters dir" do
    expect( adapters.get 'defaults' ).to be StateMate::Adapters::Defaults
  end
  
  it "should return a registered adapter" do
    obj = Object.new
    # unique name since reg is global and persistent
    name = obj.object_id.to_s
    adapters.register name, obj
    expect( adapters.get name ).to be obj
  end
end