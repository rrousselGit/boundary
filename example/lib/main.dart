import 'package:boundary/boundary.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Home());
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Boundary(
      fallbackBuilder: (_, __) => Oops(),
      child: Counter(),
    );
  }
}

class Oops extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('oops'),
    );
  }
}

class Counter extends StatefulWidget {
  @override
  _CounterState createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
