require 'json'

require 'spec_helper'

require 'state_mate/adapters/json'

describe "StateMate::Adapters::JSON.write" do
  include_context "json"

  context "root value" do
    let(:value) {
      {
        "some_key" => "some value"
      }
    }

    it "should write the value" do
      json.write filepath, value
      expect( JSON.load(File.read(filepath)) ).to eq value
    end
  end

  context "deep value" do
    let(:doc) {
      {
        "top-level-key" => {
          'second-level-key' => "old value"
        }
      }
    }

    let(:key) {
      [filepath, "top-level-key", "second-level-key"]
    }

    let(:value) {
      "new value"
    }

    before(:each) {
      File.open(filepath, 'w') do |f|
        f.write JSON.dump(doc)
      end
    }

    it "should write the value" do
      json.write key, value
      expect(
        JSON.load(File.read(filepath))[key[1]][key[2]]
      ).to eq value
    end
  end

end
