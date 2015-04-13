require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.read" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"

  let(:key) {
    'x'
  }

  context "key has string value" do

    let(:string) {
      'blah!'
    }

    before(:each) {
      `defaults write #{ DOMAIN } #{ key } -string '#{ string }' 2>&1`
    }

    it "deletes value" do
      defaults.write [DOMAIN, key], nil
      expect( defaults.read [DOMAIN, key] ).to eq nil
    end
  end

end
