require 'minitest/autorun'
require 'driving_physics/disk'

D = DrivingPhysics::Disk

describe D do
  describe "Disk.volume" do
    it "calculates the volume (m^3) of disk given radius and width" do
      cubic_m = D.volume(1.0, 1.0)
      expect(cubic_m).must_equal Math::PI

      cubic_m = D.volume(0.35, 0.2)
      expect(cubic_m).must_be_within_epsilon 0.076969
    end
  end

  describe "Disk.volume_l" do
    it "calculates the volume (L) of a disk given radius and width" do
      liters = D.volume_l(1.0, 1.0)
      expect(liters).must_equal Math::PI * 1000

      liters = D.volume_l(0.35, 0.2)
      expect(liters).must_be_within_epsilon 76.96902
    end
  end

  describe "Disk.density" do
    it "calculates the density (kg/L) given mass and volume" do
      expect(D.density(25.0, 25.0)).must_equal 1.0
      expect(D.density(50.0, 25.0)).must_equal 2.0
    end
  end

  describe "Disk.mass" do
    it "calculates the mass (kg) of a disk given radius, width, and density" do
      skip
      expect(D.mass(0.35, 0.2, D::DENSITY)).must_be_within_epsilon 25.015
    end
  end

  describe "Disk.rotational_inertia" do
    it "calculates rotational inertia for a disk given radius and mass" do
      expect(D.rotational_inertia(0.35, 25.0)).must_be_within_epsilon 1.53125
    end
  end

  describe "Disk.alpha" do
    it "calculates angular acceleration from torque and inertia" do
      scalar_torque = 1000
      inertia = D.rotational_inertia(0.35, 25.0)
      expect(D.alpha scalar_torque, inertia).must_be_within_epsilon 653.061

      vector_torque = Vector[0, 0, 1000]
      vector_alpha = D.alpha vector_torque, inertia
      expect(vector_alpha).must_be_instance_of Vector
      expect(vector_alpha.size).must_equal 3
      expect(vector_alpha[2]).must_be_within_epsilon 653.06
    end
  end

  describe "Disk.torque_vector" do
    it "calculates a torque in the 3rd dimension given 2D force and radius" do
      force = Vector[1000, 0]
      radius = Vector[0, 5]
      torque = D.torque_vector(force, radius)
      expect(torque).must_be_instance_of Vector
      expect(torque.size).must_equal 3
      expect(torque[2]).must_be_within_epsilon 5000.0
    end
  end

  describe "Disk.force_vector" do
    it "calculates a (3D) force given 3D torque and 2D radius" do
      # let's invert the Disk.torque_vector case from above:
      torque = Vector[0, 0, 5000]
      radius = Vector[0, 5]
      force = D.force_vector(torque, radius)
      expect(force).must_be_instance_of Vector
      expect(force.size).must_equal 3
      expect(force[0]).must_be_within_epsilon 1000.0

      # now let's rotate the radius into the x-dimension
      # right hand rule, positive torque means thumb into screen, clockwise
      # negative-x radius means positive-y force
      torque = Vector[0, 0, 500]
      radius = Vector[-5, 0]
      force = D.force_vector(torque, radius)
      expect(force).must_be_instance_of Vector
      expect(force.size).must_equal 3
      expect(force[1]).must_be_within_epsilon 100.0
    end
  end

  describe "instance methods" do
    before do
      @env = DrivingPhysics::Environment.new
      @disk = D.new(@env)
    end

    it "initializes" do
      skip
      expect(@disk).must_be_instance_of D
      expect(@disk.density).must_equal D::DENSITY # sanity check
      expect(@disk.mass).must_be_within_epsilon 25.01

      with_mass = D.new(@env) { |w|
        w.mass = 99.01
      }
      expect(with_mass.mass).must_equal 99.01
      expect(with_mass.density).wont_equal D::DENSITY
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
      skip
      expect(@disk.rotational_inertia).must_be_within_epsilon 1.5321
    end
  end
end
