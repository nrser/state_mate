require 'spec_helper'

require 'state_mate/adapters/git_config'

describe "StateMate::Adapters::GitConfig.read" do
  include_context "git_config"
  
  it "reads a missing key as nil" do
    expect( git_config.read key ).to eq nil
  end

  it "should error on a bad key" do
    # can't have underscore in the name
    expect{ git_config.read "state_mate.test" }.to raise_error SystemCallError
  end

  it "should read a present value" do
    value = "blah"
    `git config --global --add #{ key } #{ value }`
    expect( git_config.read key ).to eq value
  end

end
