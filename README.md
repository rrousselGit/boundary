<img
    src="https://cdn0.iconfinder.com/data/icons/poison-symbol/66/30-512.png"
    width="100px"
/> <h2>Warning, experimental project</h2>

# Boundary

Boundary is a new widget for Flutter that takes over `FlutterError.onError` and
`ErrorWidget.builder` to make them composable and scoped.

If you ever wanted to have your error reporting applied only a specific part of
your widget tree, or if you found difficult to implement an "Oops"/Loading
screen, than this library is for you.

## Installation

For `Boundary` to work, it is necessary to call `setupBoundary` first.

This can be done inside your `main` function like so:

```dart
void main() {
  setupBoundary();
  runApp(MyApp());
}
```

For tests purpose, `setupBoundary` returns a function to revert the settings
to their default behavior:

```dart
testWidgets('mytest', (tester) async {
  final restore = setupBoundary();

  await tester.pumpWidget(
    Boundary(
      fallback: (_, __) => Container(),
      child: Text('foo', textDirection: TextDirection.ltr),
    )
  );

  // necessary call before any `expect`, otherwise the test framework will throw
  restore();

  expect(find.text('foo'), findsOneWidget);
});
```

## Principle

Error reporting and fallback UI are now represented through one universal widget:

`Boundary`

This widget, when inserted inside the widget tree, is able to catch exceptions
for descendants (and only descendants) to then create a fallback UI.

Here's a typical example:

```dart
Scaffold(
  appBar: AppBar(title: const Text('hello')),
  body: Boundary(
    fallbackBuilder: (context, error) {
      return const Center(child: Text('Oops'));
    },
    child: Container(
      color: Colors.red,
      padding: const EdgeInsets.all(50),
      child: Builder(builder: (_) {
        // a descendant somethow failed
        throw 42;
      }),
    ),
  ),
);
```

Which renders the following:

![screenshot](https://raw.githubusercontent.com/rrousselGit/boundary/master/resources/example.gif?token=AEZ3I3LKSLRD32SLVLUBIMC5GRG7S)

Notice how, even if there's a `Container` with padding and a red background
as child of `Boundary`, the "Oops" screen doesn't show any of these:

The widget returned by `fallbackBuilder` is in an entirely different widget tree.

But the failing subtree (Container -> Builder) is not removed for the tree either!
Its state is preserved and it is simply offstaged, until it rebuilds successfuly.

### How to remove the fallback screen

Once an exception is thrown, the fallback screen is shown. But you may want to
stop showing that fallback at some point.

To achieve this, simply rebuild the failling widget such that it doesn't throw
anymore. This will automatically remove the fallback screen.
