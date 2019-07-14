import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef BoundaryWidgetBuilder = Widget Function(
    BuildContext context, dynamic error);

class _InheritedBoundary extends InheritedWidget {
  _InheritedBoundary({Key key, this.element, Widget child})
      : super(key: key, child: child);

  static _BoundaryElement of(BuildContext context) {
    var widget = context
        .ancestorInheritedElementForWidgetOfExactType(_InheritedBoundary)
        ?.widget;

    if (widget is _InheritedBoundary) {
      return widget.element;
    }
    return null;
  }

  final _BoundaryElement element;

  @override
  bool updateShouldNotify(_InheritedBoundary oldWidget) {
    return oldWidget.element != element;
  }
}

/// Update [FlutterError.onError] and [ErrorWidget.builder] to work with [Boundary]
///
/// The function returned can be called to restore the settings to their original
/// value.
VoidCallback setupBoundary() {
  final onError = FlutterError.onError;
  final builder = ErrorWidget.builder;

  FlutterError.onError = null;
  ErrorWidget.builder = (details) => _Fallback(details);

  return () {
    FlutterError.onError = onError;
    ErrorWidget.builder = builder;
  };
}

class Boundary extends StatelessWidget {
  const Boundary({
    Key key,
    @required this.fallbackBuilder,
    @required this.child,
  })  : assert(child != null),
        assert(fallbackBuilder != null),
        super(key: key);

  final Widget child;
  final BoundaryWidgetBuilder fallbackBuilder;

  @override
  _BoundaryElement createElement() => _BoundaryElement(this);

  Widget build(BuildContext context) {
    return _Internal(
      child: child,
      showChild: true,
      element: context as _BoundaryElement,
      exception: (context as _BoundaryElement).exception,
      fallbackBuilder: fallbackBuilder,
    );
  }
}

class _Fallback extends StatelessWidget {
  _Fallback(this.details);

  final FlutterErrorDetails details;

  @override
  _FallbackElement createElement() => _FallbackElement(this);

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FallbackElement extends StatelessElement {
  _FallbackElement(_Fallback widget) : super(widget);

  @override
  _Fallback get widget => super.widget;

  _BoundaryElement boundary;
  _BoundaryElement didCatch;

  @override
  Element updateChild(Element child, Widget newWidget, newSlot) {
    final res = super.updateChild(child, newWidget, newSlot);

    boundary = _InheritedBoundary.of(this);
    if (boundary != null) {
      boundary.markSubtreeFailed(widget.details);
    }
    return res;
  }

  @override
  void deactivate() {
    if (boundary.activated) {
      boundary.markSubtreeFailed(null);
    }
    super.deactivate();
  }
}

class _Internal extends StatelessWidget {
  const _Internal({
    Key key,
    this.element,
    this.child,
    this.fallbackBuilder,
    this.exception,
    this.showChild,
  }) : super(key: key);

  final _BoundaryElement element;
  final Widget child;
  final BoundaryWidgetBuilder fallbackBuilder;
  final dynamic exception;
  final bool showChild;

  @override
  Widget build(BuildContext context) {
    if (exception != null) {
      if (!showChild) {
        element.errorWidget = _InheritedBoundary(
          element: _InheritedBoundary.of(context),
          child: Builder(
              builder: (context) => fallbackBuilder(context, exception)),
        );
      }
    } else {
      element.errorWidget = null;
    }

    final valid = Offstage(
      offstage: !showChild && exception != null,
      child: child,
    );

    return _InheritedBoundary(
      element: element,
      child: Stack(
        alignment: Alignment.center,
        children: element.errorWidget != null
            ? [valid, element.errorWidget]
            : [valid],
      ),
    );
  }
}

class _BoundaryElement extends StatelessElement {
  _BoundaryElement(Boundary widget) : super(widget);

  @override
  Boundary get widget => super.widget;

  FlutterErrorDetails failure;
  bool isBuilding = false;
  bool activated = false;
  dynamic exception;
  Widget errorWidget;

  Element _child;
  dynamic _slot;

  @override
  Element updateChild(Element child, Widget newWidget, newSlot) {
    _child ??= child;
    _slot = newSlot;
    return _child = super.updateChild(child, newWidget, newSlot);
  }

  @override
  void performRebuild() {
    isBuilding = true;
    final hadError = failure != null;
    failure = null;
    super.performRebuild();
    isBuilding = false;
    final hasError = failure != null;
    if (hasError != hadError) {
      exception = failure?.exception;
      rebuildWithError(exception);
    }
  }

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    activated = true;
  }

  @override
  void activate() {
    super.activate();
    activated = true;
  }

  @override
  void deactivate() {
    activated = false;
    super.deactivate();
  }

  void markSubtreeFailed(FlutterErrorDetails failure) {
    this.failure = failure;
    exception = failure?.exception;
    if (!isBuilding) {
      rebuildWithError(exception);
    }
  }

  void rebuildWithError(dynamic exception) {
    updateChild(
      _child,
      _Internal(
        element: this,
        showChild: false,
        fallbackBuilder: widget.fallbackBuilder,
        exception: exception,
        child: widget.child,
      ),
      _slot,
    );
  }
}
