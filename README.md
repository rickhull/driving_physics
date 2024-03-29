[![CI Status](https://github.com/rickhull/driving_physics/actions/workflows/ci.yaml/badge.svg)](https://github.com/rickhull/driving_physics/actions/workflows/ci.yaml)

# Driving Simulation

Physical simulation of how to make a car go around a track quickly, in pure
Ruby with minimal dependencies.  Physics from first principles, often
using `Vector` class from `matrix.rb` in stdlib.

## Work In Progress

This is very much a **Work In Progress**.  Implemented so far:

### Library Features

* Spinning: rotational inertia and friction / hysteresis
* Tires: traction force via friction (static and kinetic) and the normal force
* Vectors: 2D Vector forces and 3D Vector torques
* Motor: torque curves, rotating mass with friction
* Gearbox: gear ratios, final drive, rotating mass with friction
* Powertrain: combines motor and gearbox
* Car: 4 tires, powertrain, extra mass presents a load to the powertrain
* Acceleration: via drive traction from "first principles"
* Variable clutch and throttle
* Engine braking
* Power and Energy

### mruby Support

This library is primarily a Ruby library, intended for use with CRuby (MRI),
JRuby, etc.  **mruby** is the redheaded stepchild, with significant
implications for a codebase that wants to support both sides.  Supporting
mruby here meant:

1. Editing the codebase (minimally) to avoid and remove *mruby-deadends*.
2. Creating `rake` tasks to process normal .rb files into *mruby-compatible*
   .rb files
3. Assembling all needed library .rb files into a master .rb file
4. Compiling the library to bytecode
5. Executing a toplevel/main script against the library
6. Optionally executing toplevel/main bytecode against the library

See the main Rakefile near the top for mruby stuff.

## Rationale

This is a toy project intended to scratch a personal itch: I want to create
an environment to play with performance objectives under reasonable real-world
constraints:

Primarily, one must slow down in order to navigate a curve
quickly.

All of this is done with an eye towards handing the controls over to an AI,
likely a neural net, so that it can learn (and possibly teach) techniques
that increase performance via decreasing lap times.

## Rough Notes, Thoughts, and Objectives

### Constraints:

1. cars must slow down to make tighter turns
2. cars must manage grip levels
3. equations to describe available grip
4. grip depends on tires and road surface (coefficient of grip)
5. grip "releases", whereby car controls lose effectiveness (sliding)
6. higher speed means higher turning radius
7. more mass (weight) means more grip, but also more force opposing that grip
8. one clear downside of more mass is increased tire wear and tire heat
9. tires get more grip with more heat up to a critical temp and then grip
   falls off dramatically
10. heat cycles (overheat and then cool down) reduce grip capacity over time
11. sliding dramatically increases tire wear and decreases grip
12. tire wear minimally affects grip (outside of heat cycling), up until tire
    is completely worn
13. sliding implies a gentle reduction of velocity over time, all things equal
14. wheelspin may occur on driven wheels (different from brake- or
    turn-induced sliding)
15. wheelspin incurs similar wear and heat penalties to sliding (relative
    velocity between tire and surface)

### Given These Constraints:

1. Car has enough power to create wheelspin (force applied to driven wheels
   exceeds grip-reactive force)
2. Car can achieve velocity that requires braking to successfully achieve a
   given turn radius
3. Grip level can be modeled as the ability to sustain acceleration around 1G
4. Consider slip angles and modulated sliding (e.g. threshold braking, mild
   wheelspin, limit-of-grip controlled slides)
5. Fuel consumption reduces mass over time
6. Driving outputs: gas pedal position (0-100), brake pedal position (0-100),
   steering wheel position (-100 - +100)
7. Car slows gently with 0 gas pedal
8. Car consumes fuel gently with 0 gas pedal (idle)
9. Car consumes fuel linearly with gas pedal position
10. Brakes wear with brake usage (linear plus heat factor)
11. Brakes can overheat
12. Hot brakes wear faster
13. Driving inputs: visual track position, fuel gauge, tire temp, brake temp

### Examples

Given:
* 1.0 g lateral acceleration
* 100 ft radius turn

How fast can the car go around the turn?

```
Vmax = sqrt(r) * sqrt(a) = sqrt(r*a)
Vmax = sqrt(100 ft * 32.2 ft / sec^2)
Vmax = sqrt(3220) ft/sec = 56.75 ft/sec

56.75 ft/sec * 3600 sec/hr / 5280 ft/mile
56.75 ft/sec * 3600/5280 = 38.7 mph
```
