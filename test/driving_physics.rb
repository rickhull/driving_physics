require 'minitest/autorun'
require 'driving_physics'

describe DrivingPhysics do
  F = DrivingPhysics::Force

  before do
    @mass = 1000  # kg
    @force = 7000 # N
    @weight = @mass * DrivingPhysics::G
  end

  it "calculates a reasonable drag constant" do
    expect(F.air_resistance(1)).must_be_within_epsilon 0.4257
  end

  it "approximates a reasonable rotational resistance constant" do
    expect(F::ROT_COF).must_be_within_epsilon 12.771
  end

  it "displays elapsed ms in a friendly form" do
    expect(DrivingPhysics.elapsed_display(12572358)).must_equal "03:29:32.358"
  end

  it "approximates a positive drag force" do
    expect(F.air_resistance(30)).must_be_within_epsilon 383.13
  end

  it "approximates a positive rotational resistance force" do
    expect(F.rotational_resistance(30)).must_be_within_epsilon 383.13
  end

  it "approximates a positive rolling resistance force" do
    expect(F.rolling_resistance(@weight)).must_be_within_epsilon 98.0
  end

  # see driving_physics/vector for Vector Physics
  describe "Scalar Physics" do
    it "uses F=ma to calculate acceleration given force and mass" do
      expect(DrivingPhysics.a(7000, 1000)).must_equal 7.0
    end

    it "calculates a new velocity given acceleration" do
      expect(DrivingPhysics.v(0, 7.0)).must_be_within_epsilon 0.007
      expect(DrivingPhysics.v(1.1, 7.1)).must_be_within_epsilon 1.1071
    end

    it "calculates a new position given velocity" do
      expect(DrivingPhysics.p(0, 3.0)).must_be_within_epsilon 0.003
      expect(DrivingPhysics.p(2.2, 3.5)).must_be_within_epsilon 2.2035
    end
  end
end
