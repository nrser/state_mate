$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'state_mate'

require 'nrser'

DOMAIN = 'com.nrser.state_mate'

shared_context "#{ DOMAIN } empty" do
  before(:each) {
    `defaults delete #{ DOMAIN } 2>&1 > /dev/null`
  }
end

shared_context "defaults" do
  let(:defaults) {
    StateMate::Adapters::Defaults
  }
end
