require 'json'

require 'spec_helper'

require 'state_mate/adapters/json'

describe "StateMate::Adapters::JSON.read" do
  include_context "json"
  
  it "reads an empty file as nil" do
    expect( json.read [filepath] ).to be nil
  end

  context "file with a string value in it" do
    let(:value) {
      "blah"
    }

    before(:each) {
      File.open(filepath, 'w') {|f|
        f.write JSON.dump(value)
      }
    }

    it "should read the value" do
      expect( json.read [filepath] ).to eq value
    end
  end

  context "file with a dict value in it" do
    let(:value) {
      {
        'x' => 1,
        'y' => 2,
        'z' => {
          'a' => 3,
        }
      }
    }

    before(:each) {
      File.open(filepath, 'w') {|f|
        f.write JSON.dump(value)
      }
    }

    it "should read the root value" do
      expect( json.read [filepath] ).to eq value
    end

    it "should read a deeper value" do
      expect( json.read "#{ filepath }:z:a" ).to eq 3
    end
  end

end
