require 'shellwords'

require 'spec_helper'

require 'state_mate/adapters/defaults'

def expect_defaults_read key, matcher, type
  expect( `defaults read #{ DOMAIN } #{ key.shellescape }`.chomp ).to matcher
  expect(
    `defaults read-type #{ DOMAIN } #{ key.shellescape }`.chomp
  ).to eq "Type is #{ type }"
end

def remove_whitepsace str
  str.gsub /[[:space:]]/, ''
end

RSpec::Matchers.define :struct_eq do |expected|
  match do |actual|
    remove_whitepsace(actual) == remove_whitepsace(expected)
  end
end

describe "StateMate::Adapters::Defaults.read" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"
  
  it "writes a basic value" do
    defaults.write [DOMAIN, 'x'], 'ex'
    expect_defaults_read 'x', eq('ex'), 'string'
  end
  
  it "writes a complex value" do    
    defaults.write [DOMAIN, 'one'], {'two' => 3}
    expect_defaults_read 'one', struct_eq("{two=3;}"), 'dictionary'
  end
  
  it "writes a deep key" do
    defaults.write [DOMAIN, 'one', 'two'], 3
    expect_defaults_read 'one', struct_eq("{two=3;}"), 'dictionary'
  end
  
  context "key has string values" do
    values = {'x' => 'ex', 'y' => 'why'}
    
    before(:each) {
      values.each do |key, value|
        `defaults write #{ DOMAIN } #{ key } -string '#{ value }'`
      end
    }
    
    it "clobbers with a deep key" do
      defaults.write [DOMAIN, 'x', 'two'], 3
      expect_defaults_read 'x', struct_eq("{two=3;}"), 'dictionary'
    end

    it "deletes the value when nil is written to the key" do
      # make sure they're there
      values.each do |key, value|
        expect_defaults_read key, eq(value), 'string'
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
      expect_defaults_read 'y', eq(values['y']), 'string'
      expect( defaults.read [DOMAIN, 'y'] ).to eq values['y']
    end
    
    it "deletes the whole domain when nil is written to it with no key" do
      # make sure they're there
      values.each do |key, value|
        expect_defaults_read key, eq(value), 'string'
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
