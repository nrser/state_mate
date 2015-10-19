require 'spec_helper'

require 'state_mate/adapters/pmset'

describe "StateMate::Adapters::PMSet.write" do
  include_context "pmset"
  
  it "errors when the key is not two elements" do
    expect{ pmset.write [] }.to raise_error ArgumentError
    expect{ pmset.write ["Battery Power"] }.to raise_error ArgumentError
    expect{
      pmset.write ["Battery Power", 'standbydelay', 'x']
    }.to raise_error ArgumentError
  end
  
  it "errors when a bad mode is provided" do
    expect{
      pmset.write ['Bad Mode', 'standbydelay']
    }.to raise_error ArgumentError
  end
  
  it "errors when a bad setting is provided" do
    expect{
      pmset.write ['Battery Power', 'bad setting']
    }.to raise_error ArgumentError
  end
  
  it "writes a value" do
    mode = 'AC Power'
    setting = 'standbydelay'
    key = [mode, setting]
    
    current = pmset.read key
    expect( current ).to be_instance_of String
    expect( current ).to match /^\d+$/
    
    value = '12345'
    
    begin
      pmset.write key, value
      expect( pmset.read key ).to eq value
    ensure
      # set it back where it was
      Cmds! 'sudo pmset -c %{setting} %{current}',
        setting: setting,
        current: current
    end
  end
  
  # 
  # it "reads the standbydelay setting for each section" do
  #   pmset.read([]).keys.each do |name|
  #     value = pmset.read [name, "standbydelay"]
  #     expect( value ).to be_instance_of String
  #     expect( value ).to match /^\d+$/
  #   end
  # end
  # 
  # it "fails with bad names" do
  #   expect { pmset.read ["blah"] }.to raise_error ArgumentError
  #   pmset.read([]).keys.each do |name|
  #     expect { pmset.read [name, "sdfsdf"] }.to raise_error ArgumentError
  #   end
  # end
end
