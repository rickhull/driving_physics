require 'minitest/autorun'
require 'driving_physics/disk'
require 'matrix'

include DrivingPhysics

describe Disk do
  describe "Disk.volume" do
    it "calculates the volume (m^3) of disk given radius and width" do
      cubic_m = Disk.volume(1.0, 1.0)
      expect(cubic_m).must_equal Math::PI

      cubic_m = Disk.volume(0.35, 0.2)
      expect(cubic_m).must_be_within_epsilon 0.076969
    end
  end

  describe "Disk.volume_l" do
    it "calculates the volume (L) of a disk given radius and width" do
      liters = Disk.volume_l(1.0, 1.0)
      expect(liters).must_equal Math::PI * 1000

      liters = Disk.volume_l(0.35, 0.2)
      expect(liters).must_be_within_epsilon 76.96902
    end
  end

  describe "Disk.density" do
    it "calculates the density (kg/L) given mass and volume" do
      expect(Disk.density(25.0, 25.0)).must_equal 1.0
      expect(Disk.density(50.0, 25.0)).must_equal 2.0
    end
  end

  describe "Disk.mass" do
    it "calculates the mass (kg) of a disk given radius, width, and density" do
      expect(Disk.mass(0.35, 0.2, Disk::DENSITY)).must_be_within_epsilon 76.969
    end
  end

  describe "Disk.rotational_inertia" do
    it "calculates rotational inertia for a disk given radius and mass" do
      expect(Disk.rotational_inertia(0.35, 25.0)).must_be_within_epsilon 1.53125
    end
  end

  describe "Disk.alpha" do
    it "calculates angular acceleration from torque and inertia" do
      scalar_torque = 1000
      inertia = Disk.rotational_inertia(0.35, 25.0)
      expect(Disk.alpha scalar_torque, inertia).must_be_within_epsilon 653.061

      skip unless DrivingPhysics.has_vector?
      vector_torque = Vector[0, 0, 1000]
      vector_alpha = Disk.alpha vector_torque, inertia
      expect(vector_alpha).must_be_instance_of Vector
      expect(vector_alpha.size).must_equal 3
      expect(vector_alpha[2]).must_be_within_epsilon 653.06
    end
  end

  describe "instance methods" do
    before do
      @env = DrivingPhysics::Environment.new
      @disk = Disk.new(@env)
    end

    it "initializes" do
      expect(@disk).must_be_instance_of Disk
      expect(@disk.density).must_equal Disk::DENSITY # sanity check
      expect(@disk.mass).must_be_within_epsilon 76.969

      with_mass = Disk.new(@env) { |w| w.mass = 99.01 }
      expect(with_mass.mass).must_equal 99.01
      expect(with_mass.density).wont_equal Disk::DENSITY
    end

    it "has a string representation" do
      str = @disk.to_s
      expect(str).must_be_instance_of String
      expect(str.length).must_be(:>, 5)
    end

    it "has volume" do
      expect(@disk.volume).must_be_within_epsilon 0.07697
      expect(@disk.volume_l).must_be_within_epsilon 76.96902
    end

    it "has inertia" do
      expect(@disk.rotational_inertia).must_be_within_epsilon 4.714
    end
  end
end
