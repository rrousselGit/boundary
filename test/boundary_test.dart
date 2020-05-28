// ignore_for_file: only_throw_errors
import 'package:boundary/boundary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockFlutterError extends Mock {
  void call(FlutterErrorDetails details);
}

class MockErrorBuilder extends Mock {
  Widget call(FlutterErrorDetails details);
}

VoidCallback mockErrorHandlers({
  FlutterExceptionHandler onError,
  ErrorWidgetBuilder errorBuilder,
}) {
  final o = FlutterError.onError;
  final e = ErrorWidget.builder;

  FlutterError.onError = onError;
  ErrorWidget.builder = errorBuilder;

  return () {
    FlutterError.onError = o;
    ErrorWidget.builder = e;
  };
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
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, dynamic e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: Builder(builder: (context) {
          return Defer(42);
        }),
      ),
    );

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);
  });
  testWidgets('nested exception', (tester) async {
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, dynamic e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: Container(
          child: Builder(builder: (context) {
            return Defer(42);
          }),
        ),
      ),
    );

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42));
    verifyNoMoreInteractions(builder);
  });

  testWidgets('late exception', (tester) async {
    final notifier = ValueNotifier(0);
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, dynamic e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 1) return Defer(42);
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    verifyZeroInteractions(builder);

    notifier.value++;
    await tester.pump();

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('child rebuilding after an error stops showing fallback',
      (tester) async {
    final notifier = ValueNotifier(0);
    final builder = BuilderMock();

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (c, dynamic e) {
          builder(c, e);
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 0) return Defer(42);
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    );

    clearInteractions(builder);

    notifier.value++;
    await tester.pump();

    verifyNoMoreInteractions(builder);
    expect(find.text('1'), findsOneWidget);
  });
  testWidgets(
      'both rebuilding the boundary and fixing the error simultaneously removes the fallback',
      (tester) async {
    final builder = BuilderMock();
    await tester.pumpWidget(Boundary(
      fallbackBuilder: (_, dynamic __) {
        return const Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Builder(
        builder: (context) => Defer(42),
      ),
    ));

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (_, dynamic __) {
        builder(_, __);
        return const Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Builder(
        builder: (context) =>
            const Text('42', textDirection: TextDirection.ltr),
      ),
    ));

    verifyZeroInteractions(builder);
    expect(find.text('fallback'), findsNothing);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets(
      'fallbackBuilder can throw to propagate the exception to other boundaries',
      (tester) async {
    final builder = BuilderMock();
    final builder2 = BuilderMock();

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, dynamic err) {
        builder2(c, err);
        return Container();
      },
      child: Builder(
        builder: (context) {
          return Boundary(
            fallbackBuilder: (c, dynamic err) {
              builder(c, err);
              return Defer(err);
            },
            child: Builder(builder: (_) => Defer(42)),
          );
        },
      ),
    ));

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);
  });

  testWidgets('late propagation', (tester) async {
    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, dynamic err) {
        builder2(c, err);
        return const Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary(
        fallbackBuilder: (c, dynamic err) {
          builder(c, err);
          return Defer(err);
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 1) return Defer(42);
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    ));

    verifyZeroInteractions(builder);
    verifyZeroInteractions(builder2);

    expect(find.text('0'), findsOneWidget);

    notifier.value++;
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('fallback'), findsOneWidget);

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    notifier.value++;
    await tester.pump();

    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
      'propagated error when rebuild successfuly correctly hides fallback widget',
      (tester) async {
    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary(
      fallbackBuilder: (c, dynamic err) {
        builder2(c, err);
        return const Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary(
        fallbackBuilder: (c, dynamic err) {
          builder(c, err);
          return Defer(err);
        },
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, value, __) {
            if (value == 0) return Defer(42);
            return Text(value.toString(), textDirection: TextDirection.ltr);
          },
        ),
      ),
    ));

    clearInteractions(builder);
    clearInteractions(builder2);
    expect(find.text('fallback'), findsOneWidget);

    notifier.value++;
    await tester.pump();

    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      "fallback don't lose its state when trying to rebuild child unsuccessfuly",
      (tester) async {
    var initCount = 0;

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, dynamic __) =>
            MyStateful(didInitState: () => initCount++),
        child: Builder(builder: (_) => Defer(42)),
      ),
    );

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, dynamic __) =>
            MyStateful(didInitState: () => initCount++),
        child: Builder(builder: (_) => Defer(42)),
      ),
    );

    expect(initCount, equals(1));
  });
  testWidgets('Defer without a Boundary in its ancestors report an error',
      (tester) async {
    await tester.pumpWidget(Defer(42));

    // ignore: omit_local_variable_types
    final dynamic exception = tester.takeException();

    expect(exception, isInstanceOf<BoundaryNotFoundError>());
    expect(exception.toString(), equals('''
Error: No Boundary<int> found.
'''));
  });
  testWidgets("child doesn't rebuild if didn't change and no error",
      (tester) async {
    var buildCount = 0;
    final child = Builder(builder: (_) {
      buildCount++;
      return Container();
    });

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, dynamic __) => null,
        child: child,
      ),
    );

    await tester.pumpWidget(
      Boundary(
        fallbackBuilder: (_, dynamic __) => null,
        child: child,
      ),
    );

    expect(buildCount, equals(1));
  });
  testWidgets('child is provided its constraints unmodified', (tester) async {
    final expectedConstraints = const BoxConstraints(
      minWidth: 50,
      maxWidth: 100,
      minHeight: 25,
      maxHeight: 60,
    );

    BoxConstraints actualConstraints;
    await tester.pumpWidget(
      // UnconstrainedBox to ignore tester's constraints
      UnconstrainedBox(
        child: ConstrainedBox(
          constraints: expectedConstraints,
          child: Boundary(
            fallbackBuilder: (_, dynamic __) => null,
            child: LayoutBuilder(builder: (_, constraints) {
              actualConstraints = constraints;
              return const SizedBox();
            }),
          ),
        ),
      ),
    );
    expect(actualConstraints, equals(expectedConstraints));
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
