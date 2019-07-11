import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef BoundaryWidgetBuilder = Widget Function(
    BuildContext context, dynamic error);

Widget mockError(FlutterErrorDetails details) {
  print('errored ${details.exception}');
  return _Builder(details);
}

class _Builder extends StatefulWidget {
  _Builder(this.details);

  final FlutterErrorDetails details;

  @override
  __BuilderState createState() => __BuilderState();
}

class __BuilderState extends State<_Builder> {
  RenderBoundary boundary;

  @override
  Widget build(BuildContext context) {
    boundary =
        context.ancestorRenderObjectOfType(TypeMatcher<RenderBoundary>());
    if (boundary is RenderBoundary) {
      boundary.failure = widget.details;
      print('markneedslayout $boundary');
      boundary.markNeedsLayout();
    }

    for (var b = boundary; b != null;) {
      b = b.element.ancestorRenderObjectOfType(TypeMatcher<RenderBoundary>());
      if (b != null) {
        print('markneedslayout $b');
        b.markNeedsLayout();
      }
    }
    return const SizedBox();
  }

  @override
  void deactivate() {
    if (boundary.attached) {
      boundary.markNeedsLayout();
    }
    super.deactivate();
  }
}

class Boundary<T> extends RenderObjectWidget {
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

  @override
  RenderBoundary<T> createRenderObject(BuildContext context) =>
      RenderBoundary();

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.

  Widget _build(_BoundaryElement context, dynamic error) {
    if (error != null) {
      context.errorWidget = fallbackBuilder(context, error);
    }

    final valid = Offstage(
      offstage: error != null,
      child: child,
    );

    return IndexedStack(
      alignment: Alignment.center,
      index: error != null ? 1 : 0,
      children:
          context.errorWidget != null ? [valid, context.errorWidget] : [valid],
    );
  }
}

class _BoundaryElement extends RenderObjectElement {
  _BoundaryElement(Boundary widget) : super(widget);

  @override
  Boundary get widget => super.widget;

  @override
  RenderBoundary get renderObject => super.renderObject;

  Element _child;

  Widget errorWidget;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot); // Creates the renderObject.
    renderObject.element = this;
    renderObject.callback = _layout;
  }

  @override
  void update(Boundary newWidget) {
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);
    renderObject.callback = _layout;
    renderObject.markNeedsLayout();
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.
    renderObject.markNeedsLayout();
    super
        .performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void unmount() {
    renderObject.callback = null;
    super.unmount();
  }

  void _layout(BoxConstraints constraints) {
    owner.buildScope(this, () {
      Widget built;
      try {
        built = widget._build(this, renderObject.exception);
        debugWidgetBuilderValue(widget, built);
      } catch (e, stack) {
        built = ErrorWidget.builder(_debugReportException(
            ErrorDescription('building $widget'), e, stack));
      }
      try {
        _child = updateChild(_child, built, null);
        assert(_child != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(_debugReportException(
            ErrorDescription('building $widget'), e, stack));
        _child = updateChild(null, built, slot);
      }
    });
  }

  @override
  void insertChildRenderObject(RenderObject child, dynamic slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject =
        this.renderObject;
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slot) {
    assert(false);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    final RenderBoundary renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}

class RenderBoundary<T> extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderBoundary({
    LayoutCallback<BoxConstraints> callback,
  }) : _callback = callback;

  LayoutCallback<BoxConstraints> get callback => _callback;
  LayoutCallback<BoxConstraints> _callback;
  set callback(LayoutCallback<BoxConstraints> value) {
    if (value == _callback) return;
    _callback = value;
    markNeedsLayout();
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError(
            'LayoutBuilder does not support returning intrinsic dimensions.\n'
            'Calculating the intrinsic dimensions would require running the layout '
            'callback speculatively, which might mutate the live render object tree.');
      }
      return true;
    }());
    return true;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  FlutterErrorDetails failure;
  dynamic exception;
  _BoundaryElement element;

  @override
  void performLayout() {
    print('render $this');
    final boundary =
        element.ancestorRenderObjectOfType(TypeMatcher<RenderBoundary>());

    print('first boundary $boundary');
    // if (boundary is RenderBoundary) {
    //   boundary.failure = failure;
    //   boundary.markNeedsLayout();
    //   // throw failure.exception;
    // }

    assert(callback != null);
    if (failure != null) {
      exception = failure.exception;
      failure = null;
      invokeLayoutCallback(callback);
    } else {
      invokeLayoutCallback(callback);
      if (failure != null) {
        exception = failure.exception;
        failure = null;
        invokeLayoutCallback(callback);
      }
    }
    if (failure != null) {
      print('failure $this');
      final boundary =
          element.ancestorRenderObjectOfType(TypeMatcher<RenderBoundary>());

      print('boundary $boundary');
      if (boundary is RenderBoundary) {
        boundary.failure = failure;
        boundary.markNeedsLayout();
        boundary.element.markNeedsBuild();
        throw failure.exception;
      }
    }
    failure = null;
    exception = null;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child, offset);
  }
}

FlutterErrorDetails _debugReportException(
  DiagnosticsNode context,
  dynamic exception,
  StackTrace stack,
) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'boundary library',
    context: context,
  );
  FlutterError.reportError(details);
  return details;
}
