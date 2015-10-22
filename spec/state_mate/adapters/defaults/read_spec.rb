require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.read" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"

  let(:key) {
    'x'
  }

  it "returns nil when the key is missing" do
    expect( defaults.read [DOMAIN, key] ).to be nil
  end
  
  it "reads boolean values as a booleans (not ints)" do
    bools = {
      't' => [true, 1],
      'f' => [false, 0],
    }
    
    bools.each {|key, (bool, int)|
      # write boolean values
      `defaults write #{ DOMAIN } #{ key } -boolean #{ bool }`
      
      # when it's read by `defaults read`, it says it's a boolean
      # but it returns it as an integer
      expect_defaults_read key, eq(int.to_s), 'boolean'
      
      # however, since we use `defaults export` it reads it correctly
      # as a boolean
      expect( defaults.read [DOMAIN, key] ).to be(bool)
    }
  end

  context "string value with @ in it" do

    let(:string) {
      'en_US@currency=USD'
    }

    before(:each) {
      `defaults write #{ DOMAIN } #{ key } -string '#{ string }'`
    }

    it "reads a string with an @ in it" do
      expect( defaults.read [DOMAIN, key] ).to eq string
    end
  end
  
  context "string value in current host" do

    let(:string) {
      'en_US@currency=USD'
    }

    before(:each) {
      `defaults -currentHost write #{ DOMAIN } #{ key } -string '#{ string }'`
    }

    it "reads the current host domain with a string in it" do
      expect( defaults.read DOMAIN, current_host: true ).to eq({key => string})
    end

    it "still reads the non-current host domain as empty" do
      expect( defaults.read_defaults DOMAIN ).to eq({})
    end

  end

end
