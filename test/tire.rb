require 'minitest/autorun'
require 'driving_physics/tire'

T = DrivingPhysics::Tire

describe T do
  describe "Tire.traction" do
    it "calculates traction force from normal force and coeff of friction" do
      scalar_nf = 9800 # N
      cof = 1.1
      scalar_t = T.traction(scalar_nf, cof)
      expect(scalar_t).must_equal 10780.0

      skip # Vector
      vector_nf = Vector[9800, 0]
      vector_t = T.traction(vector_nf, cof)
      expect(vector_t).must_equal Vector[10780.0, 0.0]
    end
  end

  describe "Tire.volume" do
    it "calculates the volume (m^3) of disk given radius and width" do
      cubic_m = T.volume(1.0, 1.0)
      expect(cubic_m).must_equal Math::PI

      cubic_m = T.volume(0.35, 0.2)
      expect(cubic_m).must_be_within_epsilon 0.076969
    end
  end

  describe "Tire.volume_l" do
    it "calculates the volume (L) of a disk given radius and width" do
      liters = T.volume_l(1.0, 1.0)
      expect(liters).must_equal Math::PI * 1000

      liters = T.volume_l(0.35, 0.2)
      expect(liters).must_be_within_epsilon 76.96902
    end
  end

  describe "Tire.density" do
    it "calculates the density (kg/L) given mass and volume" do
      expect(T.density(25.0, 25.0)).must_equal 1.0
      expect(T.density(50.0, 25.0)).must_equal 2.0
    end
  end

  describe "Tire.mass" do
    it "calculates the mass (kg) of a disk given radius, width, and density" do
      expect(T.mass(0.35, 0.2, T::DENSITY)).must_be_within_epsilon 25.015
    end
  end

  describe "Tire.rotational_inertia" do
    it "calculates rotational inertia for a disk given radius and mass" do
      expect(T.rotational_inertia(0.35, 25.0)).must_be_within_epsilon 1.53125
    end
  end

  describe "Tire.alpha" do
    it "calculates angular acceleration from torque and inertia" do
      scalar_torque = 1000
      inertia = T.rotational_inertia(0.35, 25.0)
      expect(T.alpha scalar_torque, inertia).must_be_within_epsilon 653.061

      skip # Vector
      vector_torque = Vector[0, 0, 1000]
      vector_alpha = T.alpha vector_torque, inertia
      expect(vector_alpha).must_be_instance_of Vector
      expect(vector_alpha.size).must_equal 3
      expect(vector_alpha[2]).must_be_within_epsilon 653.06
    end
  end

  describe "Tire.torque_vector" do
    it "calculates a torque in the 3rd dimension given 2D force and radius" do
      skip # Vector
      force = Vector[1000, 0]
      radius = Vector[0, 5]
      torque = T.torque_vector(force, radius)
      expect(torque).must_be_instance_of Vector
      expect(torque.size).must_equal 3
      expect(torque[2]).must_be_within_epsilon 5000.0
    end
  end

  describe "Tire.force_vector" do
    it "calculates a (3D) force given 3D torque and 2D radius" do
      # let's invert the Tire.torque_vector case from above:
      skip # Vector
      torque = Vector[0, 0, 5000]
      radius = Vector[0, 5]
      force = T.force_vector(torque, radius)
      expect(force).must_be_instance_of Vector
      expect(force.size).must_equal 3
      expect(force[0]).must_be_within_epsilon 1000.0

      # now let's rotate the radius into the x-dimension
      # right hand rule, positive torque means thumb into screen, clockwise
      # negative-x radius means positive-y force
      torque = Vector[0, 0, 500]
      radius = Vector[-5, 0]
      force = T.force_vector(torque, radius)
      expect(force).must_be_instance_of Vector
      expect(force.size).must_equal 3
      expect(force[1]).must_be_within_epsilon 100.0
    end
  end

  describe "instance methods" do
    before do
      @env = DrivingPhysics::Environment.new
      @tire = T.new(@env)
    end

    it "initializes" do
      expect(@tire).must_be_instance_of T
      expect(@tire.density).must_equal T::DENSITY # sanity check
      expect(@tire.mass).must_be_within_epsilon 25.01

      with_mass = T.new(@env) { |w|
        w.mass = 99.01
      }
      expect(with_mass.mass).must_equal 99.01
      expect(with_mass.density).wont_equal T::DENSITY
    end

    it "has a string representation" do
      str = @tire.to_s
      expect(str).must_be_instance_of String
      expect(str.length).must_be(:>, 5)
    end

    it "loses radius as it wears" do
      old_r = @tire.radius
      wear_amt = 50/1000r
      @tire.wear! wear_amt
      expect(@tire.radius).must_equal old_r - wear_amt
    end

    it "calculates mass from current radius" do
      expect(@tire.mass).must_be_within_epsilon 25.01
      @tire.wear!(50/1000r)
      expect(@tire.mass).must_be_within_epsilon 18.378
    end

    it "has volume" do
      expect(@tire.volume).must_be_within_epsilon 0.07697
      expect(@tire.volume_l).must_be_within_epsilon 76.96902
    end

    it "has inertia" do
      expect(@tire.rotational_inertia).must_be_within_epsilon 1.5321
    end

    it "has traction force based on normal force" do
      scalar_nf = 9800
      expect(@tire.traction scalar_nf).must_equal 10780.0
      expect(@tire.traction scalar_nf, static: false).must_equal 6860.0

      skip # Vector
      vector_nf = Vector[9800, 0]
      expect(@tire.traction vector_nf).must_equal Vector[10780.0, 0.0]
      expect(@tire.traction vector_nf, static: false).
        must_equal Vector[6860.0, 0.0]
    end

    it "determines (e.g. thrust) force based on axle torque" do
      expect(@tire.force 1000).must_be_within_epsilon 2857.143
      @tire.wear! 50/1000r
      expect(@tire.force 1000).must_be_within_epsilon 3333.333
    end

    it "determines tractable torque" do
      scalar_nf = 9800
      expect(@tire.tractable_torque scalar_nf).must_be_within_epsilon 3773.0
      kin_tq = @tire.tractable_torque scalar_nf, static: false
      expect(kin_tq).must_be_within_epsilon 2401.0

      # not sure about how torque vectors work, but the "math" "works":
      skip # Vector
      vector_nf = Vector[9800, 0]
      expect(@tire.tractable_torque(vector_nf)[0]).
        must_be_within_epsilon 3773.0
    end
  end
end
