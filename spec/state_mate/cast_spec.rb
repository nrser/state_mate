require 'spec_helper'

describe 'StateMate.cast' do
  map = {
    ['string', 'str'] => {
      'blah' => 'blah',
      1 => '1',
      24.0 => '24.0',
    },
    ['integer', 'int'] => {
      1 => 1,
      -1 => -1,
      0 => 0,
      true => 1,
      false => 0,
      '1234' => 1234,
      '-1234' => -1234,
      '+1' => 1,
      'True' => 1,
      'true' => 1,
      'False' => 0,
      'false' => 0,
      'blah' => ArgumentError,
      '3.14' => ArgumentError,
    },
    ['float'] => {
      3.14 => 3.14,
      '3.14' => 3.14,
      3 => 3.0,
      '-1.234' => -1.234,
      'blah' => ArgumentError,
      '1.2.3' => ArgumentError,
    },
    ['boolean', 'bool'] => {
      true => true,
      1 => true,
      '1' => true,
      'true' => true,
      'True' => true,
      'TRUE' => true,
      false => false,
      0 => false,
      '0' => false,
      'false' => false,
      'False' => false,
      'FALSE' => false,
    }
  }
  
  map.each do |type_names, args_and_results|
    type_names.each do |type_name|
      context "cast to #{ type_name }" do
        args_and_results.each do |value, result|
          if result.is_a?(Class) && result < Exception
            it "raises an error casting #{ value.inspect }" do
              expect { StateMate.cast type_name, value }.to raise_error result
            end
          else
            it "casts #{ value.inspect } to #{ result.inspect }" do
              expect( StateMate.cast type_name, value ).to eq result
            end
          end
        end
      end
    end
  end
end