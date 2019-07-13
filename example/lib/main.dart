import 'package:boundary/boundary.dart';
import 'package:flutter/material.dart';

final notifier = ValueNotifier(0);

void main() {
  FlutterError.onError = null;
  ErrorWidget.builder = mockError;
  runApp(MaterialApp(
    home: Scaffold(
      body: Home(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => notifier.value++,
        child: Text('+'),
      ),
    ),
  ));
}

class Home extends StatelessWidget {
  const Home({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Boundary<int>(
        fallbackBuilder: (c, err) {
          return Text('fallback', textDirection: TextDirection.ltr);
        },
        child: Boundary<String>(
          fallbackBuilder: (c, err) => throw err,
          child: ValueListenableBuilder<int>(
            valueListenable: notifier,
            builder: (_, value, __) {
              print('builder');
              if (value == 1) throw 42;
              return Text(value.toString(), textDirection: TextDirection.ltr);
            },
          ),
        ),
      ),
    );
  }
}
