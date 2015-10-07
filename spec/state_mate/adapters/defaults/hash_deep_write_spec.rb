require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.hash_deep_write!" do
  let(:defaults) {
    StateMate::Adapters::Defaults
  }

  it "does a basic set on an empty hash" do
    h = {}
    defaults.hash_deep_write! h, [:x], 1
    expect( h ).to eq({x: 1})
  end

  it "does a deep set on an empty hash" do
    h = {}
    defaults.hash_deep_write! h, [:x, :y], 1
    expect( h ).to eq({x: {y: 1}})
  end

  it "does a deep set on an non-empty hash" do
    h = {a: 1}
    defaults.hash_deep_write! h, [:x, :y], 1
    expect( h ).to eq({a: 1, x: {y: 1}})
  end

  it "clobbers values" do
    h = {x: [1, 2, 3]}
    defaults.hash_deep_write! h, [:x, :y], 1
    expect( h ).to eq({x: {y: 1}})
    
    h = {x: 'ex'}
    defaults.hash_deep_write! h, [:x, :y, :z], 1
    expect( h ).to eq({x: {y: {z: 1}}})
  end
end # hardware_uuid
