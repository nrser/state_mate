require 'spec_helper'

require 'state_mate/adapters/git_config'

describe "StateMate::Adapters::GitConfig.read" do
  include_context "git_config"
  
  it "reads a missing key as nil" do
    expect( git_config.read key ).to eq nil
  end

  context "bad key" do
    let(:bad_key) {
      "state_mate.test"
    }

    it "should error" do
      expect{ git_config.read bad_key }.to raise_error SystemCallError
    end
  end

  context "has a value" do
    let(:value) {
      "blah"
    }

    before(:each) {
      `git config --global --add #{ key } #{ value }`
    }

    it "should read the value" do
      expect( git_config.read key ).to eq value
    end
  end

end
