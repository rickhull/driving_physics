require 'minitest/autorun'
require 'driving_physics/tire'
require 'driving_physics/vector_force'

include DrivingPhysics

describe Tire do
  describe "Tire.traction" do
    it "calculates traction force from normal force and coeff of friction" do
      scalar_nf = 9800 # N
      cof = 1.1
      scalar_t = Tire.traction(scalar_nf, cof)
      expect(scalar_t).must_equal 10780.0

      skip unless DrivingPhysics.has_vector?
      vector_nf = Vector[9800, 0]
      vector_t = Tire.traction(vector_nf, cof)
      expect(vector_t).must_equal Vector[10780.0, 0.0]
    end
  end

  describe "Tire.volume" do
    it "calculates the volume (m^3) of disk given radius and width" do
      cubic_m = Tire.volume(1.0, 1.0)
      expect(cubic_m).must_equal Math::PI

      cubic_m = Tire.volume(0.35, 0.2)
      expect(cubic_m).must_be_within_epsilon 0.076969
    end
  end

  describe "Tire.volume_l" do
    it "calculates the volume (L) of a disk given radius and width" do
      liters = Tire.volume_l(1.0, 1.0)
      expect(liters).must_equal Math::PI * 1000

      liters = Tire.volume_l(0.35, 0.2)
      expect(liters).must_be_within_epsilon 76.96902
    end
  end

  describe "Tire.density" do
    it "calculates the density (kg/L) given mass and volume" do
      expect(Tire.density(25.0, 25.0)).must_equal 1.0
      expect(Tire.density(50.0, 25.0)).must_equal 2.0
    end
  end

  describe "Tire.mass" do
    it "calculates the mass (kg) of a disk given radius, width, and density" do
      expect(Tire.mass(0.35, 0.2, Tire::DENSITY)).must_be_within_epsilon 25.015
    end
  end

  describe "Tire.rotational_inertia" do
    it "calculates rotational inertia for a disk given radius and mass" do
      expect(Tire.rotational_inertia(0.35, 25.0)).must_be_within_epsilon 1.53125
    end
  end

  describe "Tire.alpha" do
    it "calculates angular acceleration from torque and inertia" do
      scalar_torque = 1000
      inertia = Tire.rotational_inertia(0.35, 25.0)
      expect(Tire.alpha scalar_torque, inertia).must_be_within_epsilon 653.061

      skip unless DrivingPhysics.has_vector?
      vector_torque = Vector[0, 0, 1000]
      vector_alpha = Tire.alpha vector_torque, inertia
      expect(vector_alpha).must_be_instance_of Vector
      expect(vector_alpha.size).must_equal 3
      expect(vector_alpha[2]).must_be_within_epsilon 653.06
    end
  end

  describe "instance methods" do
    before do
      @env = DrivingPhysics::Environment.new
      @tire = Tire.new(@env)
    end

    it "initializes" do
      expect(@tire).must_be_instance_of Tire
      expect(@tire.density).must_equal Tire::DENSITY # sanity check
      expect(@tire.mass).must_be_within_epsilon 25.01

      with_mass = Tire.new(@env) { |w|
        w.mass = 99.01
      }
      expect(with_mass.mass).must_equal 99.01
      expect(with_mass.density).wont_equal Tire::DENSITY
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

      skip unless DrivingPhysics.has_vector?
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
      skip unless DrivingPhysics.has_vector?
      vector_nf = Vector[9800, 0]
      expect(@tire.tractable_torque(vector_nf)[0]).
        must_be_within_epsilon 3773.0
    end
  end
end
