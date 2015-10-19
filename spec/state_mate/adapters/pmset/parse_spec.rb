require 'spec_helper'

require 'state_mate/adapters/pmset'

describe "StateMate::Adapters::PMSet.parse" do
  include_context "pmset"
  
  it "parses" do
    input = NRSER.dedent <<-END
    Battery Power:
     lidwake              1
     autopoweroff         1
     autopoweroffdelay    14400
     standbydelay         10800
     standby              1
     ttyskeepawake        1
     hibernatemode        3
     darkwakes            0
     gpuswitch            2
     hibernatefile        /var/vm/sleepimage
     displaysleep         5
     sleep                5
     acwake               0
     halfdim              1
     lessbright           0
     disksleep            10
    AC Power:
     Sleep On Power Button 1
     lidwake              1
     autopoweroff         0
     autopoweroffdelay    0
     standbydelay         0
     standby              0
     ttyskeepawake        1
     hibernatemode        3
     darkwakes            1
     gpuswitch            0
     hibernatefile        /var/vm/sleepimage
     womp                 0
     displaysleep         5
     networkoversleep     0
     sleep                10
     acwake               0
     halfdim              1
     disksleep            10
    END
    
    expect( pmset.parse input ).to eq({
      'Battery Power' => {
        'lidwake'              => '1',
        'autopoweroff'         => '1',
        'autopoweroffdelay'    => '14400',
        'standbydelay'         => '10800',
        'standby'              => '1',
        'ttyskeepawake'        => '1',
        'hibernatemode'        => '3',
        'darkwakes'            => '0',
        # ignored
        # 'gpuswitch'            => '2',
        'hibernatefile'        => '/var/vm/sleepimage',
        'displaysleep'         => '5',
        'sleep'                => '5',
        'acwake'               => '0',
        'halfdim'              => '1',
        'lessbright'           => '0',
        'disksleep'            => '10',
      },
      'AC Power' => {
        # ignored
        # 'Sleep On Power Button' => '1',
        'lidwake'              => '1',
        'autopoweroff'         => '0',
        'autopoweroffdelay'    => '0',
        'standbydelay'         => '0',
        'standby'              => '0',
        'ttyskeepawake'        => '1',
        'hibernatemode'        => '3',
        'darkwakes'            => '1',
        # ignored
        # 'gpuswitch'            => '0',
        'hibernatefile'        => '/var/vm/sleepimage',
        'womp'                 => '0',
        'displaysleep'         => '5',
        # ignored
        # 'networkoversleep'     => '0',
        'sleep'                => '10',
        'acwake'               => '0',
        'halfdim'              => '1',
        'disksleep'            => '10',
      },
    })
  end

end