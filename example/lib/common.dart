import 'package:flutter/material.dart';

class NotFoundError extends Error {
  NotFoundError() : super();
}

class Loading extends Error {
  Loading() : super();
}

class Menu extends StatelessWidget {
  const Menu({Key key, this.onChange}) : super(key: key);

  final ValueChanged<Future<String>> onChange;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RaisedButton(
            onPressed: () {
              onChange(
                Future.delayed(const Duration(seconds: 2))
                    .then((_) => 'Hello World'),
              );
            },
            child: Text('Future that resolves with "Hello World"'),
          ),
          RaisedButton(
            onPressed: () {
              onChange(
                Future.delayed(const Duration(seconds: 2))
                    .then((_) => throw NotFoundError()),
              );
            },
            child: Text('Future that throws a NotFoundError'),
          ),
          RaisedButton(
            onPressed: () {
              onChange(
                Future.delayed(const Duration(seconds: 2))
                    .then((_) => throw Error()),
              );
            },
            child: Text('Future that throws a random exception'),
          ),
        ],
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Text('Not found', style: Theme.of(context).textTheme.headline),
          Text("There's nothing to see here"),
        ],
      ),
    );
  }
}

class OopsScreen extends StatelessWidget {
  const OopsScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Oops, something unexpected happened'),
    );
  }
}
