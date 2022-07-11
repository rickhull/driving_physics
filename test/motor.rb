require 'minitest/autorun'
require 'driving_physics/motor'

include DrivingPhysics

describe "interpolate" do
  it "validates xs and ys match in size" do
    xs = [0, 5, 10, 15, 20]
    ys = [10, 10, 10, 10, 5]
    expect(DrivingPhysics.interpolate(1, xs: xs, ys: ys)).must_equal 10
    expect { DrivingPhysics.interpolate(1, xs: xs + [10], ys: ys) }.must_raise
    expect { DrivingPhysics.interpolate(1, xs: xs, ys: ys + [10]) }.must_raise
  end

  it "validates x is within the range of xs" do
    xs = [0, 5, 10, 15, 20]
    ys = [10, 10, 10, 10, 5]
    expect(DrivingPhysics.interpolate(1, xs: xs, ys: ys)).must_equal 10
    expect { DrivingPhysics.interpolate(-1, xs: xs, ys: ys) }.must_raise
    expect { DrivingPhysics.interpolate(25, xs: xs, ys: ys) }.must_raise
  end

  it "validates the xs are in ascending order" do
    xs = [0, 5, 10, 15, 20]
    ys = [10, 10, 10, 10, 5]
    expect(DrivingPhysics.interpolate(1, xs: xs, ys: ys)).must_equal 10
    xs[1] = 15
    expect {
      DrivingPhysics.interpolate(16, xs: xs, ys: ys)
    }.must_raise
  end

  it "performs linear interpolation to yield a y value for a valid x" do
    xs = [0, 5, 10, 15, 20]
    ys = [5, 5, 10, 10, 15]

    expect(DrivingPhysics.interpolate(0, xs: xs, ys: ys)).must_equal 5
    expect(DrivingPhysics.interpolate(1, xs: xs, ys: ys)).must_equal 5
    expect(DrivingPhysics.interpolate(4, xs: xs, ys: ys)).must_equal 5
    expect(DrivingPhysics.interpolate(5, xs: xs, ys: ys)).must_equal 5
    expect(DrivingPhysics.interpolate(6, xs: xs, ys: ys)).must_equal 6
    expect(DrivingPhysics.interpolate(7, xs: xs, ys: ys)).must_equal 7
    expect(DrivingPhysics.interpolate(8, xs: xs, ys: ys)).must_equal 8
    expect(DrivingPhysics.interpolate(9, xs: xs, ys: ys)).must_equal 9
    expect(DrivingPhysics.interpolate(10, xs: xs, ys: ys)).must_equal 10
    expect(DrivingPhysics.interpolate(11, xs: xs, ys: ys)).must_equal 10
    expect(DrivingPhysics.interpolate(12, xs: xs, ys: ys)).must_equal 10
    expect(DrivingPhysics.interpolate(14, xs: xs, ys: ys)).must_equal 10
    expect(DrivingPhysics.interpolate(15, xs: xs, ys: ys)).must_equal 10
    expect(DrivingPhysics.interpolate(16, xs: xs, ys: ys)).must_equal 11
    expect(DrivingPhysics.interpolate(17, xs: xs, ys: ys)).must_equal 12
    expect(DrivingPhysics.interpolate(18, xs: xs, ys: ys)).must_equal 13
    expect(DrivingPhysics.interpolate(19, xs: xs, ys: ys)).must_equal 14
    expect(DrivingPhysics.interpolate(20, xs: xs, ys: ys)).must_equal 15
  end
end

# shorthand
def tc(rpms, torques)
  TorqueCurve.new(rpms: rpms, torques: torques)
end

describe TorqueCurve do
  before do
    @default = TorqueCurve.new
    @rpms =    [500, 1000, 3500, 6000, 7000, 7100]
    @torques = [  0,  100,  300,  300,  250,    0]
    @minr = [0, 1]
    @mint = [0, 0]
  end

  it "maps rpm values to torque values" do
    expect(@default.torque(3500)).must_be(:>, 100)
  end

  describe "initialize" do
    it "accepts two arrays: rpms, and the corresponding torques" do
      expect(tc(@rpms, @torques)).must_be_kind_of(TorqueCurve)
    end

    it "has defaults for rpms and torques" do
      expect(@default).must_be_kind_of(TorqueCurve)
    end

    it "validates size match for rpms and torques" do
      expect(  tc(  @minr, @mint) ).must_be_kind_of TorqueCurve
      expect { tc(    [0], @mint) }.must_raise
      expect { tc([0,1,2], @mint) }.must_raise
      expect { tc(@minr,     [0]) }.must_raise
      expect { tc(@minr, [0,1,0]) }.must_raise

      rpms = [100, 2000, 30_000]
      torques = [0, 500, 0]

      expect(  tc( rpms, torques) ).must_be_kind_of TorqueCurve
      expect { tc( rpms,  [0, 0]) }.must_raise
      expect { tc([1,2], torques) }.must_raise
      expect { tc([1,2,3,4], torques) }.must_raise
    end


    describe "rpms" do
      it "validates rpms are positive" do
        expect(  tc(    @minr, @mint) ).must_be_kind_of TorqueCurve
        expect { tc([-10, 10], @mint) }.must_raise
      end

      it "validates rpms are in ascending order" do
        expect(  tc( @minr, @mint) ).must_be_kind_of TorqueCurve
        expect { tc([0, 0], @mint) }.must_raise
        expect(  tc([99, 100], @mint) ).must_be_kind_of TorqueCurve
        expect { tc([100, 99], @mint) }.must_raise
      end
    end

    describe "torques" do
      it "validates that torques start and end at zero" do
        expect(  tc(@minr, @mint) ).must_be_kind_of TorqueCurve
        expect { tc(@minr, [1,0]) }.must_raise
        expect { tc(@minr, [0,1]) }.must_raise
        expect { tc(@minr, [1,1]) }.must_raise

        expect(  tc([1,2,3], [0,500,0]) ).must_be_kind_of TorqueCurve
        expect { tc([1,2,3], [1,500,0]) }.must_raise
        expect { tc([1,2,3], [0,500,1]) }.must_raise
      end

      it "validates that torques are positive" do
        expect(  tc([1,2,3], [0, 5,0]) ).must_be_kind_of TorqueCurve
        expect { tc([1,2,3], [0,-5,0]) }.must_raise
      end
    end
  end

  it "finds the peak torque and corresponding RPM" do
    rpm, torque = *@default.peak
    expect(rpm).must_be(:>, 1000)
    expect(rpm).must_be(:<, 10_000)
    expect(torque).must_be(:>, 0)
    expect(torque).must_be(:<, 10_000)
  end

  it "interpolates to find the torque for a valid RPM" do
    tc = tc(@rpms, @torques)
    r1 = @rpms[1]
    r2 = @rpms[2]

    expect(tc.torque(r1)).must_equal @torques[1]
    expect(tc.torque(r2)).must_equal @torques[2]

    r3 = (r1 + r2) / 2
    t3 = tc.torque(r3)
    t3_expect = (@torques[1] + @torques[2]) / 2.0

    expect(t3).must_be :>, @torques[1]
    expect(t3).must_be :<, @torques[2]
    expect(t3).must_be :>=, t3_expect.floor
    expect(t3).must_be :<=, t3_expect.ceil
  end

  it "tracks min, idle, redline, and max rpms" do
    expect(@default.min).must_be :>, 0
    expect(@default.min).must_be :<, 1000
    expect(@default.idle).must_be :>, @default.min
    expect(@default.idle).must_be :<, 3000
    expect(@default.redline).must_be :>, @default.idle
    expect(@default.redline).must_be :<, 20_000
    expect(@default.max).must_be :>, @default.redline
    expect(@default.max).must_be :<, 20_000
  end
end

describe Motor do
  before do
    @default = Motor.new(Environment.new)
  end

  it "has a throttle with state" do
    expect(@default.throttle).must_equal 0.0
    @default.throttle = 0.5
    expect(@default.throttle).must_equal 0.5
    expect(@default.throttle_pct).must_equal "50.0%"

    expect { @default.throttle = 1.5 }.must_raise
  end

  it "has mass" do
    expect(@default.mass).must_be :>, 0
    expect(@default.fixed_mass).must_be :>, 0
    expect(@default.rotating_mass).must_be :>, 0
  end

  it "has a torque curve" do
    expect(@default.torque_curve).must_be_kind_of TorqueCurve
  end

  it "has idle RPM and redline RPM" do
    expect(@default.idle).must_be :>, 500
    expect(@default.idle).must_be :<, 1500

    expect(@default.redline).must_be :>, @default.idle
    expect(@default.redline).must_be :<, 10_000
  end

  it "has inertia and energy" do
    expect(@default.inertia).must_be :>, 0
    expect(@default.energy(99)).must_be :>, 0
  end

  it "determines crank alpha from torque" do
    expect(@default.alpha(50)).must_be :>, 0
  end

  it "determines torque from crank alpha" do
    a = @default.alpha(50, omega: 20)
    t = @default.implied_torque(a)
    # frictional losses
    expect(t).must_be :>, 40
    expect(t).must_be :<, 50
  end

  it "determines torque based on torque curve, RPM and throttle" do
    @default.throttle = 1.0
    expect(@default.torque(1000)).must_be :>, 0
    expect(@default.torque(3500)).must_be :>, @default.torque(1000)
  end

  it "has an engine braking effect when the throttle is closed" do
    @default.throttle = 0
    expect(@default.torque(3500)).must_be :<, 0
  end

  it "has a starter motor to get running" do
    expect(@default.starter_torque).must_be :>, 0
  end
end
