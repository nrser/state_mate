require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.read_defaults" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"

  let(:key) {
    'x'
  }

  it "returns an empty hash when the domain is empty" do
    expect( defaults.read_defaults DOMAIN ).to eq({})
  end

  context "string value" do

    let(:string) {
      'en_US@currency=USD'
    }

    before(:each) {
      `defaults write #{ DOMAIN } #{ key } -string '#{ string }'`
    }

    it "reads the domain with a string in it" do
      expect( defaults.read_defaults DOMAIN ).to eq({key => string})
    end

    it "still reads the current host domain as empty" do
      expect( defaults.read_defaults DOMAIN, true ).to eq({})
    end

  end

  context "string value in current host" do

    let(:string) {
      'en_US@currency=USD'
    }

    before(:each) {
      `defaults -currentHost write #{ DOMAIN } #{ key } -string '#{ string }'`
    }

    it "reads the domain with a string in it" do
      expect( defaults.read_defaults DOMAIN, true ).to eq({key => string})
    end

    it "still reads the current host domain as empty" do
      expect( defaults.read_defaults DOMAIN, false ).to eq({})
    end

  end

end
