// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'future_builder.dart';

void main() {
  runApp(const Gallery());
}

class Routes {
  static const String futureBuiler = '/future-builder';
}

class Gallery extends StatelessWidget {
  const Gallery({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        Routes.futureBuiler: (_) => const FutureBuilderExample(),
      },
      home: const Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
      ),
      body: ListView(
        children: <Widget>[
          const Item(
            destination: Routes.futureBuiler,
            label: 'Future Builder example',
          ),
        ],
      ),
    );
  }
}

class Item extends StatelessWidget {
  const Item({
    Key key,
    @required this.destination,
    @required this.label,
  })  : assert(label != null),
        assert(destination != null),
        super(key: key);

  final String destination;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.pushNamed(context, destination),
      title: Text(label),
    );
  }
}
