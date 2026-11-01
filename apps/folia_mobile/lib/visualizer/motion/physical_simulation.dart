import 'package:flutter/physics.dart';

import 'physical_spring.dart';

// Flutter supplies vsync only; the original Motion kernel owns positions, analytical velocity and the stopping rule.
class MotionSpringSimulation extends Simulation {
  MotionSpringSimulation(this.spring);
  final MotionPhysicalSpring spring;
  @override
  double x(double time) => spring.x(time);
  @override
  double dx(double time) => spring.dx(time);
  @override
  bool isDone(double time) => spring.isDone(time);
}
