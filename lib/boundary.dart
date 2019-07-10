import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef BoundaryWidgetBuilder = Widget Function(
    BuildContext context, dynamic error);

class Boundary extends RenderObjectWidget {
  const Boundary({
    Key key,
    @required this.builder,
  })  : assert(builder != null),
        super(key: key);

  final BoundaryWidgetBuilder builder;

  @override
  BoundaryElement createElement() => BoundaryElement(this);

  @override
  RenderBoundary createRenderObject(BuildContext context) => RenderBoundary();

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.
}

class BoundaryElement extends RenderObjectElement {
  BoundaryElement(Boundary widget) : super(widget);

  @override
  Boundary get widget => super.widget;

  @override
  RenderBoundary get renderObject => super.renderObject;

  Element _child;

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
      if (widget.builder != null) {
        try {
          built = widget.builder(this, renderObject.exception);
          debugWidgetBuilderValue(widget, built);
        } catch (e, stack) {
          built = ErrorWidget.builder(_debugReportException(
              ErrorDescription('building $widget'), e, stack));
        }
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

class RenderBoundary extends RenderBox
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

  @override
  void performLayout() {
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
    assert(failure == null);
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
    library: 'widgets library',
    context: context,
  );
  FlutterError.reportError(details);
  return details;
}