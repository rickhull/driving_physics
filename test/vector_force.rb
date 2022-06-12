require 'minitest/autorun'
require 'driving_physics/vector_force'

include DrivingPhysics

describe VectorForce do
  before do
    @drive_force = Vector[7000.0, 0.0]
    @v = Vector[3.0, 0]
    @mass = 1000
    @weight = @mass * G
  end

  it "generates uniformly random numbers centered on zero" do
    hsh = {}
    110_000.times {
      num = DrivingPhysics.random_centered_zero(5)
      hsh[num] ||= 0
      hsh[num] += 1
    }
    # note, this will fail occasionally due to chance
    hsh.values.each { |count|
      expect(count).must_be(:>=, 9000)
      expect(count).must_be(:<=, 11000)
    }
  end

  it "coerces magnitude=0 to magnitude=1" do
    a = Array.new(999) { DrivingPhysics.random_centered_zero(0) }
    expect(a.all? { |i| i == 0 }).must_equal false
  end

  it "generates a random unit vector" do
    low_res = DrivingPhysics.random_unit_vector(2, resolution: 1)
    if low_res[0] == 0.0
      expect(low_res[1].abs).must_equal 1.0
    elsif low_res[0].abs == 1.0
      expect(low_res[1]).must_equal 0.0
    elsif low_res[0].abs.round(3) == 0.707
      expect(low_res[1].abs.round(3)) == 0.707
    else
      p low_res
      raise "unexpected"
    end

    9.times {
      high_res = DrivingPhysics.random_unit_vector(3, resolution: 9)
      expect(high_res.magnitude).must_be_within_epsilon 1.0
    }
  end

  it "calculates air resistance as the square of velocity" do
    df = VectorForce.air_resistance(@v,
                                    frontal_area: 3,
                                    drag_cof: 0.1,
                                    air_density: 0.5)

    # double the velocity, drag force goes up by 4
    df2 = VectorForce.air_resistance(@v * 2,
                                     frontal_area: 3,
                                     drag_cof: 0.1,
                                     air_density: 0.5)

    expect(df2).must_equal df * 4
  end

  it "calculates the rolling resistance as a function of the normal force" do
    rr = VectorForce.rolling_resistance(@weight, dir: @v)

    # double the normal force, rolling resistance goes up by 2 (linear)
    rr2 = VectorForce.rolling_resistance(@weight * 2, dir: @v)

    expect(rr2).must_equal rr * 2
  end

  it "calculates the rotational resistance as a function of velocity" do
    rr = VectorForce.rotational_resistance(@v, rot_const: 0)
    rr2 = VectorForce.rotational_resistance(@v * 2, rot_const: 0)
    expect(rr2).must_equal rr * 2

    # now with rot_const != 0, the relationship is skewed
    rr = VectorForce.rotational_resistance(@v)
    rr2 = VectorForce.rotational_resistance(@v * 2)
    expect(rr2).wont_equal rr * 2   # because of rot_const
    expect(rr2.magnitude).must_be(:<, (rr * 2).magnitude)
  end

  it "sums resistance forces" do
    rf = VectorForce.all_resistance(@v, dir: @v, nf_mag: @weight)
    # opposite direction
    expect(rf.normalize).must_equal(-1 * @v.normalize)

    # smaller magnitude
    expect(rf.magnitude).must_be(:<, @drive_force.magnitude)
  end
end
