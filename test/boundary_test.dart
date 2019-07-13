import 'package:boundary/boundary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as prefix0;
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
    final a = mockFlutterError(null);
    final b = mockErrorWidget(mockError);

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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);
  });
  testWidgets('nested exception', (tester) async {
    final a = mockFlutterError(null);
    final b = mockErrorWidget(mockError);

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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('42'), findsOneWidget);

    verify(builder(argThat(isNotNull), 42));
    verifyNoMoreInteractions(builder);
  });

  testWidgets('late exception', (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('0'), findsOneWidget);
    verifyZeroInteractions(builder);

    mockFlutterError(null);
    mockErrorWidget(mockError);

    notifier.value++;
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    verify(builder(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('child rebuilding after an error stops showing fallback',
      (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    clearInteractions(builder);

    notifier.value++;
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    verifyNoMoreInteractions(builder);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      "fallbackBuilder can throw to propagate the exception to other boundaries",
      (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final builder2 = BuilderMock();

    await tester.pumpWidget(Boundary<int>(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Container();
      },
      child: Builder(
        builder: (context) {
          return Boundary<String>(
            fallbackBuilder: (c, err) {
              builder(c, err);
              throw err;
            },
            child: Builder(builder: (_) => throw 42),
          );
        },
      ),
    ));

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);
  });

  testWidgets("late propagation", (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary<int>(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary<String>(
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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    verifyZeroInteractions(builder);
    verifyZeroInteractions(builder2);

    expect(find.text('0'), findsOneWidget);

    notifier.value++;
    mockFlutterError(null);
    mockErrorWidget(mockError);
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('0'), findsNothing);
    expect(find.text('fallback'), findsOneWidget);

    verifyInOrder([
      builder(any, 42),
      builder2(any, 42),
    ]);
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    notifier.value++;
    mockFlutterError(null);
    mockErrorWidget(mockError);
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
      'propagated error when rebuild successfuly correctly hides fallback widget',
      (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final builder2 = BuilderMock();
    final notifier = ValueNotifier(0);

    await tester.pumpWidget(Boundary<int>(
      fallbackBuilder: (c, err) {
        builder2(c, err);
        return Text('fallback', textDirection: TextDirection.ltr);
      },
      child: Boundary<String>(
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

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    clearInteractions(builder);
    clearInteractions(builder2);
    expect(find.text('fallback'), findsOneWidget);

    notifier.value++;
    mockFlutterError(null);
    mockErrorWidget(mockError);
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;
    verifyNoMoreInteractions(builder);
    verifyNoMoreInteractions(builder2);

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets("test", (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    await tester.pumpWidget(Boundary<String>(
      fallbackBuilder: (c, err) =>
          Text(err.toString(), textDirection: TextDirection.ltr),
      child: RepaintBoundary(
        child: Center(child: Builder(builder: (_) => throw 42)),
      ),
    ));

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('42'), findsOneWidget);
  });
  testWidgets("child doesn't rebuild if didn't change and no error",
      (tester) async {
    int buildCount = 0;
    final child = Builder(builder: (_) {
      buildCount++;
      return Container();
    });

    await tester.pumpWidget(
      Boundary<String>(
        fallbackBuilder: (_, __) => null,
        child: child,
      ),
    );

    await tester.pumpWidget(
      Boundary<String>(
        fallbackBuilder: (_, __) => null,
        child: child,
      ),
    );

    expect(buildCount, equals(1));
  });
  test("child does rebuild if didn't change but error", () {}, skip: true);
}

class BuilderMock extends Mock {
  Widget call(BuildContext context, dynamic error);
}
