require 'minitest/autorun'
require 'driving_physics/vector'

describe DrivingPhysics::Vector do
  V = DrivingPhysics::Vector

  before do
    @drive_force = Vector[7000.0, 0.0]
    @v = Vector[3.0, 0]
    @mass = 1000
    @weight = @mass * DrivingPhysics::G

    # note, we're in a 2D world and normal force is typically on z-axis
    # generally we're just using the magnitude so it doesn't matter
    @normal_force = Vector[0.0, @weight]
  end

  it "generates uniformly random numbers centered on zero" do
    hsh = {}
    110_000.times {
      num = V.random_centered_zero(5)
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
    a = Array.new(999) { V.random_centered_zero(0) }
    expect(a.all? { |i| i == 0 }).must_equal false
  end

  it "generates a random unit vector" do
    low_res = V.random_unit_vector(2, resolution: 1)
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
      high_res = V.random_unit_vector(3, resolution: 9)
      expect(high_res.magnitude).must_be_within_epsilon 1.0
    }
  end

  it "calculates air resistance as the square of velocity" do
    drag_force = V.force_drag_full(drag_coefficient: 0.1,
                                   frontal_area: 3,
                                   air_density: 0.5,
                                   velocity: @v)
    # double the velocity, drag force goes up by 4
    df2 = V.force_drag_full(drag_coefficient: 0.1,
                            frontal_area: 3,
                            air_density: 0.5,
                            velocity: @v * 2)
    expect(df2).must_equal drag_force * 4
  end

  it "calculates the rolling resistance as a function of the normal force" do
    rr = V.force_rolling_resistance_full(drive_force: @drive_force,
                                         normal_force: @normal_force,
                                         coefficient: V::CRF)

    # double the normal force, rolling resistance goes up by 2 (linear)
    rr2 = V.force_rolling_resistance_full(drive_force: @drive_force,
                                          normal_force: @normal_force * 2,
                                          coefficient: V::CRF)
    expect(rr2).must_equal rr * 2
  end

  it "just uses mass (and G) to calculate rolling resistance" do
    rr = V.force_rolling_resistance_full(drive_force: @drive_force,
                                         normal_force: @normal_force,
                                         coefficient: V::CRF)
    rr2 = V.force_rolling_resistance(drive_force: @drive_force,
                                     mass: @mass)
    expect(rr2).must_equal rr
  end

  it "calculates the rotational resistance as a function of velocity" do
    rr = V.force_rotational_resistance(@v)
    rr2 = V.force_rotational_resistance(@v * 2)
    expect(rr2).must_equal rr * 2
  end

  it "has a simplified air_resistance that just needs velocity" do
    drag = V.force_air_resistance(@v)
    drag2 = V.force_air_resistance(@v * 2)
    expect(drag2).must_equal drag * 4
  end

  it "sums drive force and simplified resistance forces" do
    ndf = V.net_drive_force(drive_force: @drive_force,
                            velocity: @v,
                            mass: @mass)
    # same direction
    expect(ndf.normalize).must_equal(@drive_force.normalize)

    # smaller magnitude
    expect(ndf.magnitude).must_be(:<, @drive_force.magnitude)
  end
end
