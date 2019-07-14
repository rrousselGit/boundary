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

## Principle

Error reporting and fallback UI are now represented through one universal widget:

`Boundary`

This widget, when inserted inside the widget tree, is able to catch exceptions
for descendants (and only descendants) to then create a fallback UI.

It is typically used as such:

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

In this example,
