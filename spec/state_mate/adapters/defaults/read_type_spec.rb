require 'spec_helper'

require 'state_mate/adapters/defaults'

describe "StateMate::Adapters::Defaults.read_type" do
  include_context "defaults"
  include_context "#{ DOMAIN } empty"

  {
    string: 'en_US@currency=USD',
    data:   '62706c697374',
    int:    '1',
    float:  '1',
    bool:   'true',
    date:   '2014-03-27',
    array:  '1 2 3',
    dict:   'x 1 y 2',
  }.each do |type, input|

    it "reads a #{ type } type" do
      `defaults write #{ DOMAIN } x -#{ type } #{ input }`
      expect( defaults.read_type DOMAIN, 'x', false ).to be type
    end

    it "reads a #{ type } type from current host" do
      `defaults -currentHost write #{ DOMAIN } x -#{ type } #{ input }`
      expect( defaults.read_type DOMAIN, 'x', true ).to be type
    end    

  end

end
