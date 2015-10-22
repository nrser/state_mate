require 'spec_helper'

describe "StateMate::array_contains" do
  missing = "missing"
  key = 'k'
  value = 'v'
  
  table = {
  # input | desired           | create  | clobber | success?
    [nil,   [value]] =>      [[ missing,  missing,  false, ],
                              [ missing,  false,    false, ],
                              [ missing,  true,     true, ],
                              [ false,    missing,  false, ],
                              [ false,    false,    false, ],
                              # this is the weird one... you've said you want 
                              # to clobber but you explicity said you don't
                              # want to create... what do we do with that?
                              # 
                              # right now, it will create the array with the
                              # value as the only element (clobber overrides
                              # create)
                              [ false,    true,     true, ],
                              [ true,     missing,  true, ],
                              [ true,     false,    true, ],
                              [ true,     true,     true, ], ],
    ['x',   [value]] =>        [[ missing,  missing,  false, ],
                              [ missing,  false,    false, ],
                              [ missing,  true,     true, ],
                              [ false,    missing,  false, ],
                              [ false,    false,    false, ],
                              [ false,    true,     true, ],
                              [ true,     missing,  false, ],
                              [ true,     false,    false, ],
                              [ true,     true,     true, ], ],
    [[], [value]]  =>          [[ missing,  missing,  true, ],
                              [ missing,  false,    true, ],
                              [ missing,  true,     true, ],
                              [ false,    missing,  true, ],
                              [ false,    false,    true, ],
                              [ false,    true,     true, ],
                              [ true,     missing,  true, ],
                              [ true,     false,    true, ],
                              [ true,     true,     true, ], ],
    [['x'], ['x', value]] => [[ missing,  missing,  true, ],
                              [ missing,  false,    true, ],
                              [ missing,  true,     true, ],
                              [ false,    missing,  true, ],
                              [ false,    false,    true, ],
                              [ false,    true,     true, ],
                              [ true,     missing,  true, ],
                              [ true,     false,    true, ],
                              [ true,     true,     true, ], ],
    [[value], [value]] =>    [[ missing,  missing,  true, ],
                              [ missing,  false,    true, ],
                              [ missing,  true,     true, ],
                              [ false,    missing,  true, ],
                              [ false,    false,    true, ],
                              [ false,    true,     true, ],
                              [ true,     missing,  true, ],
                              [ true,     false,    true, ],
                              [ true,     true,     true, ], ],
  }
  
  table.each do |(current, desired), stuff|
    context "current value is #{ current.inspect }" do
      stuff.each do |(create, clobber, success)|
        context "create is #{ create } and clobber is #{ clobber }" do
          options = {}
          options[:create] = create unless create === missing
          options[:clobber] = clobber unless clobber === missing
          if success
            it "returns #{ desired.inspect }" do
              expect(
                StateMate.array_contains key, current, value, options
              ).to eq desired
            end
          else
            it "raises an error" do
              expect {
                StateMate.array_contains key, current, value, options
              }.to raise_error StateMate::Error::StructureConflictError
            end
          end
        end
      end
    end
  end
  
end