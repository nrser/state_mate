require 'spec_helper'

describe "StateMate.array_missing?" do
  key = 'k'
  value = 'v'
  
  context "current is nil" do
    let(:current){ nil }
    
    it "should return false with no options" do
      expect(
        StateMate.array_missing? key, current, value, nil, {}
      ).to be false
    end
    
    it "should return true with :unset_ok true" do
      expect(
        StateMate.array_missing? key, current, value, nil, unset_ok: true
      ).to be true
    end
  end # current is nil
end

describe "StateMate.array_missing" do
  key = 'k'
  value = 'v'
  
  context "current is nil" do
    let(:current){ nil }
    
    it "should error with no options" do
      expect {
        StateMate.array_missing key, current, value, {}
      }.to raise_error StateMate::Error::StructureConflictError
    end
    
    it "should return [] if :create or :clobber are set" do
      [{create: true}, {clobber: true}].each do |options|
        expect(StateMate.array_missing key, current, value, options).to eq []
      end
    end
    
    it "should return nil if :unset_ok is true" do
      expect(
        StateMate.array_missing key, current, value, unset_ok: true
      ).to eq nil
    end
  end # current is nil
  
  context "current is not nil but not an array" do
    let(:current){ 'x' }
    
    it "should error with no options" do
      expect {
        StateMate.array_missing key, current, value, {}
      }.to raise_error StateMate::Error::StructureConflictError
    end
    
    it "should error if :create is set but not :clobber" do
      expect {
        StateMate.array_missing key, current, value, create: true
      }.to raise_error StateMate::Error::StructureConflictError
    end
    
    it "should return [] if :clobber is set" do
      expect(
        StateMate.array_missing key, current, value, clobber: true
      ).to eq []
    end
    
  end # current is not nil but not an array

  context "current is an array that contains the value" do
    let(:current){ ['x', value, 'y'] }
    
    it "should remove the value" do
      expect(
        StateMate.array_missing key, current, value, {}
      ).to eq ['x', 'y']
    end
    
  end # current is an array that contains the value
  
  context "current is an array that does not contain the value" do
    let(:current){ ['x', 'y'] }
    
    it "should leave it alone" do
      expect(
        StateMate.array_missing key, current, value, {}
      ).to eq ['x', 'y']
    end
    
  end # current is an array that does not contain the value
end