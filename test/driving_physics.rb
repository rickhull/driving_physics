require 'minitest/autorun'
require 'driving_physics'

describe DrivingPhysics do
  it "displays elapsed ms in a friendly form" do
    expect(DrivingPhysics.elapsed_display 12572358).must_equal "03:29:32.358"
  end

  it "calculates kph from m/s" do
    expect(DrivingPhysics.kph 23.2).must_equal 83.52
  end

  describe "Scalar Physics" do
    # these functions also work with vectors
    it "uses F=ma to calculate acceleration given force and mass" do
      expect(DrivingPhysics.acc 7000, 1000).must_equal 7.0
    end

    it "calculates a new velocity given acceleration" do
      expect(DrivingPhysics.vel 0.0, 7.0).must_be_within_epsilon 0.007
      expect(DrivingPhysics.vel 1.1, 7.1).must_be_within_epsilon 1.1071
    end

    it "calculates a new position given velocity" do
      expect(DrivingPhysics.pos 0.0, 3.0).must_be_within_epsilon 0.003
      expect(DrivingPhysics.pos 2.2, 3.5).must_be_within_epsilon 2.2035
    end
  end
end
