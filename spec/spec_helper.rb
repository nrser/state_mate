require 'tempfile'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'state_mate'

DOMAIN = 'com.nrser.state_mate'

shared_context "#{ DOMAIN } empty" do
  before(:each) {
    `defaults delete #{ DOMAIN } 2>&1 > /dev/null`
    `defaults -currentHost delete #{ DOMAIN } 2>&1 > /dev/null`
  }
end

shared_context "defaults" do
  let(:defaults) {
    StateMate::Adapters::Defaults
  }
end

shared_context "git_config" do
  let(:git_config) {
    StateMate::Adapters::GitConfig
  }

  let(:section) {
    "statemate"
  }

  let(:key) {
    "#{ section }.test"
  }

  before(:each) {
    `git config --global --unset-all #{ key } 2>&1`
  }

  after(:each) {
    `git config --global --unset-all #{ key } 2>&1`
    `git config --global --remove-section #{ section } 2>&1`
  }
end

shared_context "json" do
  let(:json) {
    StateMate::Adapters::JSON
  }
  
  before(:each) {
    @f = Tempfile.new "state_mate_json_spec"
    @filepath = @f.path
  }
  
  after(:each) {
    @f.close
    @f.unlink
  }
end

def expect_defaults_read key, matcher, type
  expect( `defaults read #{ DOMAIN } #{ key.shellescape }`.chomp ).to matcher
  expect(
    `defaults read-type #{ DOMAIN } #{ key.shellescape }`.chomp
  ).to eq "Type is #{ type }"
end

def remove_whitepsace str
  str.gsub /[[:space:]]/, ''
end

RSpec::Matchers.define :struct_eq do |expected|
  match do |actual|
    remove_whitepsace(actual) == remove_whitepsace(expected)
  end
end
