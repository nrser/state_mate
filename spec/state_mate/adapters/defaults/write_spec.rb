require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.read" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"

  context "key has string value" do
    values = {'x' => 'ex', 'y' => 'why'}
    
    before(:each) {
      values.each do |key, value|
        `defaults write #{ DOMAIN } #{ key } -string '#{ value }'`
      end
    }

    it "deletes the value when nil is written to the key" do
      # make sure they're there
      values.each do |key, value|
        expect( `defaults read #{ DOMAIN } #{ key }`.chomp ).to eq value
      end
      
      # do the delete by writing `nil`
      defaults.write [DOMAIN, 'x'], nil
      
      # check that it's gone via the system command
      expect(
        `defaults read #{ DOMAIN } x 2>&1`
      ).to match /does\ not\ exist$/
      
      # and check that it's gone to us
      expect( defaults.read [DOMAIN, 'x'] ).to eq nil
      
      # and check that the other one is still there
      expect( `defaults read #{ DOMAIN } y`.chomp ).to eq values['y']
      expect( defaults.read [DOMAIN, 'y'] ).to eq values['y']
    end
    
    it "deletes the whole domain when nil is written to it with no key" do
      # make sure they're there
      values.each do |key, value|
        expect( `defaults read #{ DOMAIN } #{ key }`.chomp ).to eq value
      end
      
      # do the delete by writing `nil`
      defaults.write [DOMAIN], nil
      
      values.each do |key, value|
        # check that it's gone via the system command
        expect(
          `defaults read #{ DOMAIN } #{ key } 2>&1`
        ).to match /does\ not\ exist$/
        
        # and check that it's gone to us
        expect( defaults.read [DOMAIN, key] ).to eq nil
      end
    end
  end
  
  it "errors trying to write an empty domain or key" do
    [
      [DOMAIN, ''],
      [''],
      [],
      '',
      # these are actually ok, for some reason it drops trailing empty strings:
      # "#{ DOMAIN }:",
      # "#{ DOMAIN }::",
      # but not leading ones:
      ":#{ DOMAIN }",
      # or ones with non-empty following
      "#{ DOMAIN }::x",
    ].each do |key|
      expect {
        defaults.write key, nil
      }.to raise_error ArgumentError
    end
  end

end
