require 'driving_physics/tire'
require 'minitest/autorun'

include DrivingPhysics

describe Tire do
  TP = Tire::TemperatureProfile

  describe TP do
    before do
      @tp = TP.new
    end

    it "initializes with two same-sized arrays" do
      expect(@tp).must_be_kind_of TP
      expect(TP.new([0,1,2,3], [0,1.0,0.7,0.4])).wont_be_nil
      expect { TP.new('', '') }.must_raise ArgumentError
      expect { TP.new([]) }.must_raise ArgumentError
      expect { TP.new([0], []) }.must_raise ArgumentError
      expect { TP.new([], [0.0]) }.must_raise ArgumentError
    end

    it "determines a grip number from a temp number" do
      { -500 => TP::MIN_GRIP,
        -100 => 0.1,
        -0.0001 => 0.1,
        0.0 => 0.5
      }.each { |temp, gf| expect(@tp.grip_factor(temp)).must_equal gf }
    end

    it "has a critical_temp above the temp for 100%" do
      expect(@tp.critical_temp).must_be(:>, 90)
      expect(@tp.critical_temp).must_equal 105
    end

    it "has a map that increases to 100% and decreases below 80%" do
      expect {
        TP.new([0,1,2,3,4], [0.0,0.1,0.2,0.3,0.4])
      }.must_raise TP::Error

      expect {
        TP.new([0,1,2,3,4], [0.0, 1.0, 0.99, 0.98, 0.97])
      }.must_raise TP::Error
    end
  end

  before do
    @t = Tire.new
  end

  it "initializes with default values without a block" do
    expect(@t).must_be_kind_of Tire
  end

  it "accepts a block to initialize with custom values" do
    t = Tire.new { |x|
      x.tread_mm = 9999
      x.g_factor = -0.1234
    }

    expect(t.tread_mm).must_equal 9999
    expect(t.g_factor).must_equal -0.1234
  end

  it "calculates a dynamic tread depth based on condition" do
    expect(@t.tread_depth).must_equal @t.tread_mm
    expect(@t.tread_depth).must_equal @t.tread_mm * @t.condition.tread_pct
    @t.condition.tread_pct = 0.5
    expect(@t.tread_depth).must_equal @t.tread_mm * @t.condition.tread_pct
  end

  it "knows when the tread is gone" do
    expect(@t.tread_left?).must_equal true
    @t.condition.tread_pct = 0.00001
    expect(@t.tread_left?).must_equal false
  end

  it "has 10% grip when down to the cords" do
    expect(@t.tread_factor).must_equal 1.0
    @t.condition.tread_pct = 0.0
    expect(@t.tread_factor).must_equal 0.1
  end

  it "has less than 10% tread factor when the cords start to wear" do
    expect(@t.condition.tread_pct).must_equal 1.0
    expect(@t.tread_factor).must_equal 1.0
    @t.condition.tread_pct = 0.5
    expect(@t.tread_factor).must_equal 1.0

    @t.condition.tread_pct = 0.0
    expect(@t.tread_factor).must_be_within_epsilon 0.1
    @t.condition.cords_pct = 0.9
    expect(@t.tread_factor).must_be_within_epsilon 0.09
  end

  it "has decreasing heat cycle factor" do
    expect(@t.condition.heat_cycles).must_equal 0
    expect(@t.heat_cycle_factor).must_equal 1.0
    @t.condition.heat_cycles = 20
    expect(@t.heat_cycle_factor).must_be(:<, 1.0)
  end

  it "has a temp factor according to temperature profile" do
    expect(@t.condition.temp_c).must_equal 25
    expect(@t.temp_factor).must_equal 0.75
    @t.condition.temp_c = 90
    expect(@t.temp_factor).must_equal 1.0
  end

  it "incorporates temp, heat_cycles, and tread depth into available grip" do
    @t.condition.temp_c = 60
    expect(@t.temp_factor).must_be_within_epsilon 0.8
    @t.condition.heat_cycles = 10
    expect(@t.heat_cycle_factor).must_be_within_epsilon 0.96
    @t.condition.tread_pct = 0.5
    expect(@t.tread_factor).must_equal 1.0

    expect(@t.max_g).must_be_within_epsilon 0.768

    @t.condition.tread_pct = 0.0001
    expect(@t.max_g).must_be_within_epsilon 0.0768
  end
end
