require 'spec_helper'

require 'state_mate/adapters/pmset'

describe "StateMate::Adapters::PMSet.read" do
  include_context "pmset"
  
  it "reads all the settings" do
    expect( pmset.read [] ).to be_instance_of Hash
  end
  
  it "reads the standbydelay setting for each section" do
    pmset.read([]).keys.each do |name|
      value = pmset.read [name, "standbydelay"]
      expect( value ).to be_instance_of String
      expect( value ).to match /^\d+$/
    end
  end
  
  it "fails with bad names" do
    expect { pmset.read ["blah"] }.to raise_error ArgumentError
    pmset.read([]).keys.each do |name|
      expect { pmset.read [name, "sdfsdf"] }.to raise_error ArgumentError
    end
  end
end
