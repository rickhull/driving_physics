require 'minitest/autorun'
require 'driving_physics/motor'

include DrivingPhysics

describe "interpolate" do
  it "validates xs and ys match in size" do
  end

  it "validates x is within the range of xs" do
  end

  it "validates the xs are in ascending order" do
  end

  it "performs linear interpolation to yield a y value for a valid x" do
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
