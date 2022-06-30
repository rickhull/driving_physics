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

describe TorqueCurve do
  it "maps rpm values to torque values" do
  end

  describe "initialize" do
    it "accepts two arrays: rpms, and the corresponding torques" do
    end

    it "validates the sizes of rpms and torques match" do
    end

    describe "rpms" do
      it "validates rpms are positive" do
      end

      it "validates rpms are in ascending order" do
      end
    end

    describe "torques" do
      it "validates that torques start and end at zero" do
      end

      it "validates that torques are positive" do
      end
    end
  end

  it "finds the peak torque and corresponding RPM" do
  end

  it "interpolates to find the torque for a valid RPM" do
  end

  it "tracks min, idle, redline, and max rpms" do
  end
end

describe Motor do
  it "has a throttle with state" do
  end

  it "has mass" do
  end

  it "has rotating mass" do
  end

  it "has a torque curve" do
  end

  it "has idle RPM and redline RPM" do
  end

  it "has inertia and energy" do
  end

  it "determines crank alpha from torque" do
  end

  it "determines torque from crank alpha" do
  end

  it "has inertial and friction losses in its output torque" do
  end

  it "determines input torque based on torque curve and throttle" do
  end

  it "has an engine braking effect when the throttle is closed" do
  end

  it "has a starter motor to get running" do
  end
end
