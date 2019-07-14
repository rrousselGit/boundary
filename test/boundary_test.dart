import 'package:boundary/boundary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

ErrorWidgetBuilder mockErrorWidget(ErrorWidgetBuilder builder) {
  final origin = ErrorWidget.builder;
  ErrorWidget.builder = builder;
  return origin;
}

FlutterExceptionHandler mockFlutterError(FlutterExceptionHandler builder) {
  final origin = FlutterError.onError;
  FlutterError.onError = builder;
  return origin;
}

void main() {
  testWidgets("fallback isn't called if child succeeds", (tester) async {
    final key = GlobalKey();
    final builder = BuilderMock();

    await tester.pumpWidget(Boundary(
      key: key,
      fallbackBuilder: builder,
      child: const Text('foo', textDirection: TextDirection.ltr),
    ));

    expect(find.text('foo'), findsOneWidget);
    expect(key.currentContext, isNotNull);
    verifyZeroInteractions(builder);
  });
  testWidgets('root exception', (tester) async {
    final restore = setupBoundary();

    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: Builder(builder: (context) {
          throw 42;
        }),
      ),
    );

    restore();

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);
  });
  testWidgets('nested exception', (tester) async {
    final restore = setupBoundary();

    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: Container(child: Builder(builder: (context) {
          throw 42;
        })),
      ),
    );

    restore();

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42));
    verifyNoMoreInteractions(builder);
  });

  testWidgets('late exception', (tester) async {
    final restore = setupBoundary();

    final notifier = ValueNotifier(0);
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: ValueListenableBuilder(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 1) throw 42;
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    );

    restore();

    expect(find.text('0'), findsOneWidget);
    verifyZeroInteractions(builder);

    setupBoundary();

    notifier.value++;
    await tester.pump();

    restore();

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('child rebuilding after an error stops showing fallback',
      (tester) async {
    final restore = setupBoundary();

    final notifier = ValueNotifier(0);
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: ValueListenableBuilder(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 0) throw 42;
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    );

    restore();

    clearInteractions(builder);

    notifier.value++;
    await tester.pump();

    restore();

    verifyNoMoreInteractions(builder);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      "fallbackBuilder can throw to propagate the exception to other boundaries",
      (tester) async {
    final restore = setupBoundary();

    final builder = BuilderMock();
    final builder2 = BuilderMock();

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Container();
      },
      child: Builder(
        builder: (context) {
          return Boundary(
            fallbackBuilder: (c, err) {
              builder(c, err);
              throw err;
            },
            child: Builder(builder: (_) => throw 42),
          );
        },
      ),
    ));

    restore();

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);
  });

  testWidgets("late propagation", (tester) async {
    final restore = setupBoundary();

    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary(
        fallbackBuilder: (c, err) {
          builder(c, err);
          throw err;
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 1) throw 42;
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    ));

    restore();

    verifyZeroInteractions(builder);
    verifyZeroInteractions(builder2);

    expect(find.text('0'), findsOneWidget);

    notifier.value++;
    setupBoundary();
    await tester.pump();

    restore();

    expect(find.text('0'), findsNothing);
    expect(find.text('fallback'), findsOneWidget);

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    notifier.value++;
    setupBoundary();
    await tester.pump();

    restore();
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
      'propagated error when rebuild successfuly correctly hides fallback widget',
      (tester) async {
    final restore = setupBoundary();

    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary(
        fallbackBuilder: (c, err) {
          builder(c, err);
          throw err;
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 0) throw 42;
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    ));

    restore();

    clearInteractions(builder);
    clearInteractions(builder2);
    expect(find.text('fallback'), findsOneWidget);

    notifier.value++;
    setupBoundary();
    await tester.pump();

    restore();
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets("test", (tester) async {
    final restore = setupBoundary();

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, err) =>
          Text(err.toString(), textDirection: TextDirection.ltr),
      child: RepaintBoundary(
        child: Center(child: Builder(builder: (_) => throw 42)),
      ),
    ));

    restore();

    expect(find.text('42'), findsOneWidget);
  });
  testWidgets(
      "fallback don't lose its state when trying to rebuild child unsuccessfuly",
      (tester) async {
    final restore = setupBoundary();
    var initCount = 0;

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, __) => MyStateful(didInitState: () => initCount++),
        child: Builder(builder: (_) => throw 42),
      ),
    );

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, __) => MyStateful(didInitState: () => initCount++),
        child: Builder(builder: (_) => throw 42),
      ),
    );

    restore();

    expect(initCount, equals(1));
  });
  testWidgets("child doesn't rebuild if didn't change and no error",
      (tester) async {
    int buildCount = 0;
    final child = Builder(builder: (_) {
      buildCount++;
      return Container();
    });

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, __) => null,
        child: child,
      ),
    );

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, __) => null,
        child: child,
      ),
    );

    expect(buildCount, equals(1));
  });
}

class BuilderMock extends Mock {
  Widget call(BuildContext context, dynamic error);
}

class MyStateful extends StatefulWidget {
  const MyStateful({Key key, this.didInitState}) : super(key: key);

  final VoidCallback didInitState;

  @override
  _MyStatefulState createState() => _MyStatefulState();
}

class _MyStatefulState extends State<MyStateful> {
  @override
  void initState() {
    super.initState();
    widget.didInitState?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
