require 'minitest/autorun'
require 'driving_physics/scalar_force'

describe DrivingPhysics::ScalarForce do
  DP = DrivingPhysics
  F = DP::ScalarForce

  # i.e. multiply this number times speed^2 to approximate drag force
  it "calculates a reasonable drag constant" do
    expect(F.air_resistance 1).must_be_within_epsilon DP::DRAG
  end

  # ROT_COF's value is from observing that rotational resistance
  # matches air resistance at roughly 30 m/s in street cars
  it "approximates a reasonable rotational resistance constant" do
    expect(30 * F.air_resistance(1)).must_be_within_epsilon DP::ROT_COF
  end

  it "approximates a positive drag force" do
    expect(F.air_resistance 30).must_be_within_epsilon 383.13
  end

  it "approximates a positive rotational resistance force" do
    expect(F.rotational_resistance 30).must_be_within_epsilon 383.13
  end

  it "approximates a positive rolling resistance force" do
    normal_force = 1000 * DP::G
    expect(F.rolling_resistance normal_force).must_be_within_epsilon 98.0
  end
end
