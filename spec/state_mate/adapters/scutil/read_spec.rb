require 'spec_helper'

require 'state_mate/adapters/scutil'

describe "StateMate::Adapters::SCUtil.read" do
  # there doesn't seem to be any way to simply remove keys with `scutil`
  # so we're just going to loop over the known keys and make sure the
  # read does what we think it should. it's kind of stupid / redundant, but
  # it's better than nothing.
  ['ComputerName', 'LocalHostName', 'HostName'].each do |key|
    result = Cmds 'scutil --get %{key}', key: key
    
    if result.ok?
      it "reads the correct value for present key #{ key }" do
        expect( StateMate::Adapters::SCUtil.read key ).to eq result.out.chomp
      end
    else
      it "reads `nil` for absent key #{ key }" do
        expect( StateMate::Adapters::SCUtil.read key ).to eq nil
      end
    end
  end

  it "errors on a bad key" do
    # can't have underscore in the name
    expect{ StateMate::Adapters::SCUtil.read "blah" }.to raise_error SystemCallError
  end

end
