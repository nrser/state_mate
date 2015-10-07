require 'spec_helper'

require 'state_mate/adapters/git_config'

describe "StateMate::Adapters::GitConfig.read" do
  include_context "git_config"

  it "writes a value" do
    value = "blah"
    git_config.write key, value
    expect( `git config --global --get #{ key }`.chomp ).to eq "#{ value }"
  end
end
