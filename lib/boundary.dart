import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef BoundaryWidgetBuilder = Widget Function(
    BuildContext context, dynamic error);

class InheritedBoundary extends InheritedWidget {
  InheritedBoundary({Key key, this.element, Widget child})
      : super(key: key, child: child);

  static BoundaryElement of(BuildContext context) {
    var widget = context
        .ancestorInheritedElementForWidgetOfExactType(InheritedBoundary)
        ?.widget;

    if (widget is InheritedBoundary) {
      return widget.element;
    }
    return null;
  }

  final BoundaryElement element;

  @override
  bool updateShouldNotify(InheritedBoundary oldWidget) {
    return oldWidget.element != element;
  }
}

Widget mockError(FlutterErrorDetails details) {
  return _Builder(details);
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

  BoundaryElement boundary;

  @override
  Element updateChild(Element child, Widget newWidget, newSlot) {
    final res = super.updateChild(child, newWidget, newSlot);

    boundary = InheritedBoundary.of(this);
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

  final BoundaryElement element;
  final Widget child;
  final BoundaryWidgetBuilder fallbackBuilder;
  final dynamic exception;

  @override
  Widget build(BuildContext context) {
    if (element.propagating && !element.startPropa) {
      return element.cache;
    }

    if (exception != null) {
      element.errorWidget = InheritedBoundary(
        element: InheritedBoundary.of(context),
        child: fallbackBuilder(element, exception),
      );
    }

    final valid = Offstage(
      offstage: exception != null,
      child: child,
    );

    return element.cache = InheritedBoundary(
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

class Boundary<T> extends StatelessWidget {
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
  BoundaryElement createElement() => BoundaryElement(this);

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.

  Widget build(BuildContext context) {
    return _Internal(
      child: child,
      element: context as BoundaryElement,
      fallbackBuilder: fallbackBuilder,
    );
  }
}

class BoundaryElement extends StatelessElement {
  BoundaryElement(Boundary widget) : super(widget);

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
    if (!isBuilding) {
      rebuildWithError(failure?.exception);
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
