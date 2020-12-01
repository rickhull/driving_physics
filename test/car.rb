require 'minitest/autorun'
require 'driving_physics/car'

C = DrivingPhysics::Car

describe C do
  before do
    @env = DrivingPhysics::Environment.new
    @c = C.new(@env)
  end

  def get_moving
    @c.controls.brake_pedal = 0.0
    @c.controls.drive_pedal = 1.0
    @c.add_fuel 10
    50.times { @c.tick! }
    expect(@c.condition.speed).must_be :>, 0.0
  end


  it "initializes" do
    expect(@c).must_be_instance_of C
  end

  it "has a string representation" do
    str = @c.to_s
    expect(str).must_be_instance_of String
    expect(str.length).must_be(:>, 5)
  end

  it "adds fuel and reports overflow" do
    expect(@c.condition.fuel).must_equal 0.0
    @c.add_fuel 10.0
    expect(@c.condition.fuel).must_equal 10.0
    overflow = @c.add_fuel @c.fuel_capacity
    expect(@c.condition.fuel).must_equal @c.fuel_capacity
    expect(overflow).must_equal 10.0
  end

  it "varies drive_force based on drive_pedal and available fuel" do
    expect(@c.drive_force).must_equal 0.0  # no pedal
    @c.controls.drive_pedal = 1.0
    expect(@c.drive_force).must_equal 0.0  # no fuel
    @c.add_fuel 10

    expect(@c.drive_force).must_equal @c.max_drive_force  # vroom!
  end

  it "has a drive vector in direction of @dir" do
    @c.add_fuel 10
    @c.controls.drive_pedal = 1.0
    dv = @c.drive_force_vector
    expect(dv).must_be_instance_of Vector
    dvn = dv.normalize
    [0,1].each { |dim|
      expect(dvn[dim]).must_be_within_epsilon @c.condition.dir[dim]
    }
  end

  it "varies brake_force based on brake_pedal" do
    expect(@c.brake_force).must_equal 0.0  # no pedal
    @c.controls.brake_pedal = 1.0
    expect(@c.brake_force).must_equal @c.max_brake_force
  end

  it "has a brake vector opposing movement or @dir" do
    # hmm, no good way to go in reverse
    # just test against forward movement for now
    @c.controls.brake_pedal = 1.0
    bv = @c.brake_force_vector
    expect(bv).must_be_instance_of Vector
    bvn = bv.normalize
    [0,1].each { |dim|
      expect(bvn[dim]).must_be_within_epsilon -1 * @c.condition.dir[dim]
    }

    get_moving

    @c.controls.drive_pedal = 0.0
    @c.controls.brake_pedal = 1.0
    bdir = @c.brake_force_vector.normalize
    vdir = @c.condition.vel.normalize
    [0,1].each { |dim|
      expect(bdir[dim]).must_be_within_epsilon -1 * vdir[dim]
    }
  end

  it "tracks the mass of remaining fuel" do
    expect(@c.fuel_mass).must_equal 0.0
    @c.add_fuel 10
    expect(@c.fuel_mass).must_be_within_epsilon 7.1
  end

  it "tracks total_mass including fuel and driver" do
    expect(@c.total_mass).must_equal @c.mass + @c.driver_mass
    @c.add_fuel 10
    expect(@c.total_mass).must_equal @c.mass + @c.fuel_mass + @c.driver_mass
  end

  it "computes the total weight based on G" do
    expect(@c.weight).must_be_within_epsilon 10535.0
  end

  it "computes resistance forces based on instance variables" do
    air = @c.air_resistance
    expect(air).must_be_kind_of Vector
    expect(air.magnitude).must_equal 0.0

    rot = @c.rotational_resistance
    expect(rot).must_be_kind_of Vector
    expect(rot.magnitude).must_equal 0.0

    roll = @c.rolling_resistance
    expect(roll).must_be_kind_of Vector
    expect(roll.magnitude).must_be :>, 0
  end

  describe C::Condition do
    before do
      @cond = @c.condition
    end

    it "intializes" do
      expect(@cond).must_be_kind_of C::Condition
    end

    it "has a string representation" do
      str = @cond.to_s
      expect(str).must_be_kind_of String
      expect(str.length).must_be :>, 5
    end

    it "has a lateral direction clockwise from @dir" do
      lat = @cond.lat_dir
      expect(lat).must_be_kind_of Vector
      expect(lat.magnitude).must_be_within_epsilon 1.0
      expect(lat.independent?(@cond.dir)).must_equal true
    end

    it "has a movement_dir based on velocity, or @dir when stopped" do
      md = @cond.movement_dir
      expect(md).must_be_kind_of Vector
      expect(md.magnitude).must_be_within_epsilon 1.0
      expect(md).must_equal @cond.dir

      get_moving
      md = @cond.movement_dir
      expect(md).must_be_kind_of Vector
      expect(md.magnitude).must_be_within_epsilon 1.0
      vd = @cond.vel.normalize
      [0,1].each { |dim|
        expect(md[dim]).must_be_within_epsilon vd[dim]
      }
    end
  end
end
