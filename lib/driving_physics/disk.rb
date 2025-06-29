module DrivingPhysics
  # represents a rotating mass, particularly for inertia, friction calculations
  # mass in kg, radius and extent in m,
  # a sensible density is that of water: 1 kg/L (1000 kg/m^3) (1 g/mL^3)
  class Disk < Data.define(:mass, :radius, :extent)
    def self.revs(rads) = rads * 0.5 / Math::PI
    def self.rads(revs) = revs *  2  * Math::PI
    def self.omega(rpm) = self.rads(rpm / 60.0)
    def self.rpm(omega) = self.revs(omega) * 60.0

    def self.inertia(mass, radius) = 0.5 * mass * radius ** 2
    def self.volume(radius, extent) = Math::PI * radius ** 2 * extent    # m^3
    def self.liters(radius, extent) = self.volume(radius, extent) * 1000 # L
    def self.density(mass, liters) = mass.to_f / liters
    def self.tangential(rotational, radius) = rotational * radius
    def self.rotational(tangental, radius) = tangential.to_f / radius
    def self.torque(force, radius) = self.tangential(force, radius)
    def self.force(torque, radius) = self.rotational(torque, radius)
    def self.alpha(torque, inertia) = torque.to_f / inertia
    def self.energy(omega, inertia) = 0.5 * inertia * omega ** 2

    def inertia = Disk.inertia(mass, radius)
    def volume = Disk.volume(radius, extent)
    def liters = Disk.liters(radius, extent)
    def density = Disk.density(mass, self.liters)
    def tangential(rotational) = Disk.tangential(rotational, radius)
    def rotational(tangential) = Disk.rotational(tangential, radius)
    def torque(force) = Disk.torque(force, radius)
    def force(torque) = Disk.force(torque, radius)
    def alpha(torque) = Disk.alpha(torque, self.inertia)
    def energy(omega) = Disk.energy(omega, self.inertia)
  end
end
