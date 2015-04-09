require 'spec_helper'

require 'state_mate/adapters/git_config'

describe "StateMate::Adapters::GitConfig.read" do
  include_context "git_config"

  let(:value) {
    "blah"
  }

  it "writes a value" do
    git_config.write key, value

    expect( `git config --global --get #{ key }`.chomp ).to eq "#{ value }"
  end
end
