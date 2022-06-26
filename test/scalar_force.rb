require 'minitest/autorun'
require 'driving_physics/scalar_force'

include DrivingPhysics

describe ScalarForce do
  # i.e. multiply this number times speed^2 to approximate drag force
  it "calculates a reasonable drag constant" do
    expect(ScalarForce.air_resistance 1).must_be_within_epsilon(-1 * DRAG)
  end

  # ROT_COF's value is from observing that rotational resistance
  # matches air resistance at roughly 30 m/s in street cars
  it "approximates a reasonable rotational resistance constant" do
    _(30 * ScalarForce.air_resistance(1)).must_be_within_epsilon(-1 * ROT_COF)
  end

  it "approximates a positive drag force" do
    expect(ScalarForce.air_resistance 30).must_be_within_epsilon(-383.13)
  end

  it "approximates a positive rotational resistance force" do
    _(ScalarForce.rotational_resistance 30).must_be_within_epsilon(-383.13)
  end

  it "approximates a positive rolling resistance force" do
    _(ScalarForce.rolling_resistance(1000 * G)).must_be_within_epsilon(-98.0)
  end
end
