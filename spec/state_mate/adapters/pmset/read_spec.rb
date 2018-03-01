require 'spec_helper'

require 'state_mate/adapters/pmset'

describe "StateMate::Adapters::PMSet.read" do
  include_context "pmset"
  
  it "reads all the settings" do
    expect( pmset.read [] ).to be_instance_of Hash
  end
  
  it "reads the setting values for each section" do
    pmset.read([]).each do |section, values|
      values.each do |name, value|
        read_value = pmset.read [section, name]
        expect( read_value ).to eq value
      end
    end
  end
  
  it "fails with bad names" do
    expect { pmset.read ["blah"] }.to raise_error ArgumentError
    pmset.read([]).keys.each do |name|
      expect { pmset.read [name, "sdfsdf"] }.to raise_error ArgumentError
    end
  end
end
