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

end
