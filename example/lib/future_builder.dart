import 'package:boundary/boundary.dart';
import 'package:flutter/material.dart';

class FutureBuilderExample extends StatefulWidget {
  const FutureBuilderExample({Key key}) : super(key: key);

  @override
  _FutureBuilderExampleState createState() => _FutureBuilderExampleState();
}

class _FutureBuilderExampleState extends State<FutureBuilderExample> {
  Key key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FutureBuilder example')),
      body: Boundary(
        fallbackBuilder: (_, error) {
          if (error is Loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (error is NotFoundError) {
            return const NotFoundScreen();
          } else {
            return const OopsScreen();
          }
        },
        child: _FutureExample(key: key),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => key = UniqueKey()),
        child: Icon(Icons.restore),
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

class _FutureExample extends StatefulWidget {
  const _FutureExample({Key key}) : super(key: key);

  @override
  __FutureExampleState createState() => __FutureExampleState();
}

class __FutureExampleState extends State<_FutureExample> {
  Future<String> future;

  @override
  Widget build(BuildContext context) {
    print('hey');
    if (future == null) return _Menu(onChange: onFutureChange);
    return FutureBuilder<String>(
      future: future,
      builder: (_, snapshot) {
        print('future ${snapshot.hasData} ${snapshot.hasError}');
        if (snapshot.hasError) throw snapshot.error;
        if (!snapshot.hasData) throw Loading();

        return Text(snapshot.data);
      },
    );
  }

  void onFutureChange(value) {
    setState(() {
      future = value;
    });
  }
}

class _Menu extends StatelessWidget {
  const _Menu({Key key, this.onChange}) : super(key: key);

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

class NotFoundError extends Error {
  NotFoundError() : super();
}

class Loading extends Error {
  Loading() : super();
}
