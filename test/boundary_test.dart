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
    final a = mockFlutterError(null);
    final b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
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

    verify(builder(key.currentContext, 42)).called(1);
    verifyNoMoreInteractions(builder);
  });
  testWidgets('nested exception', (tester) async {
    final a = mockFlutterError(null);
    final b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
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

    verify(builder(key.currentContext, 42));
    verifyNoMoreInteractions(builder);
  });
  testWidgets('late exception', (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final notifier = ValueNotifier(0);
    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
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

    verify(builder(key.currentContext, 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('late exception', (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final notifier = ValueNotifier(0);
    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
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

    verify(builder(key.currentContext, 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);
  });
  testWidgets('child rebuilding after an error stops showing fallback',
      (tester) async {
    var a = mockFlutterError(null), b = mockErrorWidget(mockError);

    final notifier = ValueNotifier(0);
    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
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
        print('helo');
        builder2(c, err);
        return Container();
      },
      child: Boundary<String>(
        fallbackBuilder: (c, err) {
          builder(c, err);
          throw err;
        },
        child: Builder(builder: (_) => throw 42),
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
  }, skip: true);
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
  test("child doesn't rebuild if didn't change and no error", () {},
      skip: true);
  test("child does rebuild if didn't change but error", () {}, skip: true);
}

class BuilderMock extends Mock {
  Widget call(BuildContext context, dynamic error);
}
