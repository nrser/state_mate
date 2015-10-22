require 'spec_helper'

describe 'StateMate::Adapters.register' do
  include_context 'adapters'
  
  it "should error when `name` is not a string" do
    expect {
      adapters.register :blah, nil
    }.to raise_error TypeError
  end
  
  it "should key registered object under it's name in @@index" do
    obj = Object.new
    # unique name since reg is global and persistent
    name = obj.object_id.to_s
    adapters.register name, obj
    index = adapters.class_variable_get :@@index
    expect(index).to be_instance_of Hash
    expect(index.key? name).to be true
    expect(index[name]).to be obj
  end
end