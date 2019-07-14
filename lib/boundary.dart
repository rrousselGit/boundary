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
  ErrorWidget.builder = (details) => _Builder(details);

  return () {
    FlutterError.onError = onError;
    ErrorWidget.builder = builder;
  };
}

class _Builder extends StatelessWidget {
  _Builder(this.details);

  final FlutterErrorDetails details;

  @override
  _BuilderElement createElement() => _BuilderElement(this);

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _BuilderElement extends StatelessElement {
  _BuilderElement(_Builder widget) : super(widget);

  @override
  _Builder get widget => super.widget;

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
  const _Internal(
      {Key key, this.element, this.child, this.fallbackBuilder, this.exception})
      : super(key: key);

  final _BoundaryElement element;
  final Widget child;
  final BoundaryWidgetBuilder fallbackBuilder;
  final dynamic exception;

  @override
  Widget build(BuildContext context) {
    if (element.propagating && !element.startPropa) {
      return element.cache;
    }

    if (exception != null) {
      element.errorWidget = _InheritedBoundary(
        element: _InheritedBoundary.of(context),
        child:
            Builder(builder: (context) => fallbackBuilder(context, exception)),
      );
    } else {
      element.errorWidget = null;
    }

    final valid = Offstage(
      offstage: exception != null,
      child: child,
    );

    return element.cache = _InheritedBoundary(
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

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.

  Widget build(BuildContext context) {
    return _Internal(
      child: child,
      element: context as _BoundaryElement,
      exception: (context as _BoundaryElement).exception,
      fallbackBuilder: fallbackBuilder,
    );
  }
}

class _BoundaryElement extends StatelessElement {
  _BoundaryElement(Boundary widget) : super(widget);

  @override
  Boundary get widget => super.widget;

  Widget errorWidget;
  bool propagating = false;
  bool startPropa = false;
  Widget cache;
  dynamic error;
  FlutterErrorDetails failure;
  bool isBuilding = false;
  bool activated = false;
  dynamic exception;

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
    failure = null;
    super.performRebuild();
    isBuilding = false;
    if (failure != null) {
      final exception = failure.exception;
      failure = null;
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
        fallbackBuilder: widget.fallbackBuilder,
        exception: exception,
        child: widget.child,
      ),
      _slot,
    );
  }
}
