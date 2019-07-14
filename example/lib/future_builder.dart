// ignore_for_file: public_member_api_docs
import 'package:boundary/boundary.dart';
import 'package:flutter/material.dart';

import 'common.dart';

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
        fallbackBuilder: (_, dynamic error) {
          // FutureBuilderExample doesn't have the reference on the Future, but
          // is still able to display loading/error state
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

class _FutureExample extends StatefulWidget {
  const _FutureExample({Key key}) : super(key: key);

  @override
  __FutureExampleState createState() => __FutureExampleState();
}

class __FutureExampleState extends State<_FutureExample> {
  Future<String> future;

  @override
  Widget build(BuildContext context) {
    if (future == null) return Menu(onChange: onFutureChange);
    return FutureBuilder<String>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          // ignore: only_throw_errors
          throw snapshot.error;
        }
        if (!snapshot.hasData) throw Loading();

        return Text(snapshot.data);
      },
    );
  }

  void onFutureChange(Future<String> value) {
    setState(() {
      future = value;
    });
  }
}
