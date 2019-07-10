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
  testWidgets('description', (tester) async {
    final key = GlobalKey();
    final builder = BuilderMock();
    when(builder(any, any))
        .thenReturn(const Text('foo', textDirection: TextDirection.ltr));

    await tester.pumpWidget(Boundary(key: key, builder: builder));

    expect(find.text('foo'), findsOneWidget);
    expect(key.currentContext, isNotNull);
    verify(builder(key.currentContext, null)).called(1);
    verifyNoMoreInteractions(builder);
  });
  testWidgets('root exception', (tester) async {
    final a = mockFlutterError(null);
    final b = mockErrorWidget(mockError);

    final builder = BuilderMock();
    final key = GlobalKey();

    await tester.pumpWidget(
      Boundary(
        key: key,
        builder: (c, e) {
          builder(c, e);

          if (e == null) throw 42;
          return Text(e.toString(), textDirection: TextDirection.ltr);
        },
      ),
    );

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('42'), findsOneWidget);

    verifyInOrder([
      builder(key.currentContext, null),
      builder(key.currentContext, 42),
    ]);
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
        builder: (c, e) {
          builder(c, e);
          if (e == null) {
            return Builder(
              builder: (_) {
                throw 42;
              },
            );
          } else {
            return Text(e.toString(), textDirection: TextDirection.ltr);
          }
        },
      ),
    );

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('42'), findsOneWidget);

    verifyInOrder([
      builder(key.currentContext, null),
      builder(key.currentContext, 42),
    ]);
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
        builder: (c, e) {
          builder(c, e);
          if (e == null) {
            return ValueListenableBuilder(
              valueListenable: notifier,
              builder: (_, value, __) {
                if (value == 1) throw 42;
                return Text(value.toString(), textDirection: TextDirection.ltr);
              },
            );
          } else {
            return Text(e.toString(), textDirection: TextDirection.ltr);
          }
        },
      ),
    );

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('0'), findsOneWidget);
    verify(builder(key.currentContext, null)).called(1);
    verifyNoMoreInteractions(builder);

    mockFlutterError(null);
    mockErrorWidget(mockError);

    notifier.value++;
    await tester.pump();

    FlutterError.onError = a;
    ErrorWidget.builder = b;

    verify(builder(key.currentContext, 42)).called(1);
    verifyNoMoreInteractions(builder);

    expect(find.text('42'), findsOneWidget);

    mockFlutterError(null);
    mockErrorWidget(mockError);

    notifier.value++;
    await tester.pumpWidget(
      Boundary(
        key: key,
        builder: (c, e) {
          builder(c, e);
          return ValueListenableBuilder(
            valueListenable: notifier,
            builder: (_, value, __) {
              return Text(value.toString(), textDirection: TextDirection.ltr);
            },
          );
        },
      ),
    );
    FlutterError.onError = a;
    ErrorWidget.builder = b;

    expect(find.text('2'), findsOneWidget);
    verify(builder(key.currentContext, null)).called(1);
    verifyNoMoreInteractions(builder);

  });
}

Widget mockError(details) {
  return Builder(
    builder: (context) {
      final boundary =
          context.ancestorRenderObjectOfType(TypeMatcher<RenderBoundary>());
      if (boundary is RenderBoundary) {
        boundary.failure = details;
      }
      return const SizedBox();
    },
  );
}

class BuilderMock extends Mock {
  Widget call(BuildContext context, dynamic error);
}
