require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.hardware_uuid" do
  let(:defaults) {
    StateMate::Adapters::Defaults
  }

  it "returns something that looks like an apple hardware uuid" do
    expect( defaults.hardware_uuid ).to(
      match /[0-9A-F]{8}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{4}\-[0-9A-F]{12}/
    )
  end
end # hardware_uuid
