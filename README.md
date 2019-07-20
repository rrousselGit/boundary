<img
    src="https://cdn0.iconfinder.com/data/icons/poison-symbol/66/30-512.png"
    width="100px"
/> <h2>Warning, experimental project</h2>

# Boundary

Boundary is a set of widgets that takes over `FlutterError.onError` and
`ErrorWidget.builder` to make them composable and scoped.

If you found difficult to implement an "Oops"/Loading" screen or want
explicit error reporting for only a specific subtree, then this library is
for you.

## Principle

Fallback UI are represented through one universal widget:

`Boundary`

This widget, when inserted inside the widget tree, is able to catch exceptions
from descendants (and only descendants) to then create a fallback UI.

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
        // a descendant somethow wants to abort the build
        return Defer(42);
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

This is proved by the [following example](https://github.com/rrousselGit/boundary/blob/master/example/lib/future_builder.dart),
which shows how `Boundary` can be used to show a loading/error screen from a
`FutureBuilder` deeper in the widget tree – without having a reference on
the `Future`.

```dart
Boundary(
  fallbackBuilder: (_, error) {
    // doesn't have the reference on the Future, but
    // is still able to display loading/error state
    if (error is Loading) {
      return const Center(child: CircularProgressIndicator());
    } else if (error is NotFoundError) {
      return const NotFoundScreen();
    } else {
      return const OopsScreen();
    }
  },
  child: SubtreeThatHasAFutureBuilder(),
)
```

![future builder example](https://raw.githubusercontent.com/rrousselGit/boundary/master/resources/future_builder.gif?token=AEZ3I3NDM2W3MC34RXS5YXS5GSIEK)

## FAQ

### How to remove the fallback screen

Once an exception is thrown, the fallback screen is shown. But you may want to
stop showing that fallback at some point.

To achieve this, simply rebuild the failling widget such that it doesn't throw
anymore. This will automatically remove the fallback screen.

### What happens if there's an exception inside `fallbackBuilder`?

If there's an exception inside `fallbackBuilder`, then the exception is propagated
to the next `Boundary`, until there are none anymore.

```dart
Boundary(
  fallbackBuilder: (_, err) => Text(err.toString()),
  child: Boundary(
    fallbackBuilder: (_, err) {
      print(err);
      return Defer(err);
    },
    child: Builder(builder: (_) {
      return Defer(42);
    })
  )
)
```

Using the previous snippet, this will first print `42` in the console, then
render a `Text` with "42" on screen.
