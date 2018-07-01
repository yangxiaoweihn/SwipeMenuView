import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const Curve _kResizeTimeCurve = const Interval(0.4, 1.0, curve: Curves.ease);
const double _kMinFlingVelocity = 700.0;
const double _kMinFlingVelocityDelta = 400.0;
const double _kFlingVelocityScale = 1.0 / 300.0;
const double _kDismissThreshold = 0.4;

typedef void DismissDirectionCallback(DismissDirection direction);

class SlideMenuWidget extends StatefulWidget {
    const SlideMenuWidget({
        @required Key key,
        @required this.child,
        @required this.menusWidth,
        this.background,
        this.secondaryBackground,
        this.onResize,
        this.onDismissed,
        this.direction: DismissDirection.horizontal,
        this.resizeDuration: const Duration(milliseconds: 300),
        this.dismissThresholds: const <DismissDirection, double>{},
        this.movementDuration: const Duration(milliseconds: 200),
        this.crossAxisEndOffset: 0.0,
    }) : assert(key != null),
        assert(secondaryBackground != null ? background != null : true),
        assert(secondaryBackground != null ? (menusWidth != null && menusWidth > 0): true),
        super(key: key);

    final Widget child;

    final Widget background;

    final Widget secondaryBackground;
    final double menusWidth;

    final VoidCallback onResize;

    final DismissDirectionCallback onDismissed;

    final DismissDirection direction;

    final Duration resizeDuration;

    final Map<DismissDirection, double> dismissThresholds;

    final Duration movementDuration;

    final double crossAxisEndOffset;

    @override
    _DismissibleState createState() => new _DismissibleState();
}

class _DismissibleClipper extends CustomClipper<Rect> {
    _DismissibleClipper({
        @required this.axis,
        @required this.moveAnimation
    }) : assert(axis != null),
        assert(moveAnimation != null),
        super(reclip: moveAnimation);

    final Axis axis;
    final Animation<Offset> moveAnimation;

    @override
    Rect getClip(Size size) {
        assert(axis != null);
        switch (axis) {
            case Axis.horizontal:
                final double offset = moveAnimation.value.dx * size.width;
                if (offset < 0)
                    return new Rect.fromLTRB(size.width + offset, 0.0, size.width, size.height);
                return new Rect.fromLTRB(0.0, 0.0, offset, size.height);
            case Axis.vertical:
              final double offset = moveAnimation.value.dy * size.height;
              if (offset < 0)
                  return new Rect.fromLTRB(0.0, size.height + offset, size.width, size.height);
              return new Rect.fromLTRB(0.0, 0.0, size.width, offset);
        }
        return null;
    }

    @override
    Rect getApproximateClipRect(Size size) => getClip(size);

    @override
    bool shouldReclip(_DismissibleClipper oldClipper) {
        return oldClipper.axis != axis
            || oldClipper.moveAnimation.value != moveAnimation.value;
    }
}

enum _FlingGestureKind { none, forward, reverse }

class _DismissibleState extends State<SlideMenuWidget> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin { // ignore: MIXIN_INFERENCE_INCONSISTENT_MATCHING_CLASSES
    @override
    void initState() {
        super.initState();
        _moveController = new AnimationController(duration: widget.movementDuration, vsync: this)
            ..addStatusListener(_handleDismissStatusChanged)
            ..addListener(() {
                print('----------   ${_moveController.value}  $_dragExtent  ${this._menuFilter()}  ${_moveController.velocity}');
            })
        ;
        _updateMoveAnimation();
    }

    AnimationController _moveController;
    Animation<Offset> _moveAnimation;

    AnimationController _resizeController;
    Animation<double> _resizeAnimation;

    double _dragExtent = 0.0;
    bool _dragUnderway = false;
    Size _sizePriorToCollapse;

    @override
    bool get wantKeepAlive => _moveController?.isAnimating == true || _resizeController?.isAnimating == true;

    @override
    void dispose() {
        _moveController.dispose();
        _resizeController?.dispose();
        super.dispose();
    }

    bool get _directionIsXAxis {
      return widget.direction == DismissDirection.horizontal
          || widget.direction == DismissDirection.endToStart
          || widget.direction == DismissDirection.startToEnd;
    }

    DismissDirection _extentToDirection(double extent) {
        if (extent == 0.0)
            return null;
        if (_directionIsXAxis) {
            switch (Directionality.of(context)) {
                case TextDirection.rtl:
                    return extent < 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
                case TextDirection.ltr:
                    return extent > 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
            }
            assert(false);
            return null;
        }
        return extent > 0 ? DismissDirection.down : DismissDirection.up;
    }

    DismissDirection get _dismissDirection => _extentToDirection(_dragExtent);

    bool get _isActive {
        return _dragUnderway || _moveController.isAnimating;
    }

    double get _overallDragAxisExtent {
        final Size size = context.size;
        return _directionIsXAxis ? size.width : size.height;
    }

    void _handleDragStart(DragStartDetails details) {
        _dragUnderway = true;
        if (_moveController.isAnimating) {
            _dragExtent = _moveController.value * _overallDragAxisExtent * _dragExtent.sign;
            _moveController.stop();
        } else {
            _dragExtent = 0.0;
            _moveController.value = 0.0;
        }
        setState(() {
            _updateMoveAnimation();
        });
    }

    void _handleDragUpdate(DragUpdateDetails details) {
        if (!_isActive || _moveController.isAnimating)
            return;

        final double delta = details.primaryDelta;
        final double oldDragExtent = _dragExtent;

        switch (widget.direction) {
            case DismissDirection.horizontal:
            case DismissDirection.vertical:
                _dragExtent += delta;
                break;

            case DismissDirection.up:
                if (_dragExtent + delta < 0)
                    _dragExtent += delta;
                break;

            case DismissDirection.down:
                if (_dragExtent + delta > 0)
                    _dragExtent += delta;
                break;

            case DismissDirection.endToStart:
                switch (Directionality.of(context)) {
                    case TextDirection.rtl:
                        if (_dragExtent + delta > 0)
                            _dragExtent += delta;
                    break;
                    case TextDirection.ltr:
                        if (_dragExtent + delta < 0)
                            _dragExtent += delta;
                    break;
                }
                break;

            case DismissDirection.startToEnd:
                switch (Directionality.of(context)) {
                    case TextDirection.rtl:
                        if (_dragExtent + delta < 0)
                            _dragExtent += delta;
                        break;
                    case TextDirection.ltr:
                        if (_dragExtent + delta > 0)
                            _dragExtent += delta;
                        break;
                }
            break;
        }

        //TODO
//        print('----old: $oldDragExtent');
        if(this._menuFilter()) {
            _moveController.value = widget.menusWidth / _overallDragAxisExtent;
            return;
        }

        //TODO

        if (oldDragExtent.sign != _dragExtent.sign) {
            setState(() {
                _updateMoveAnimation();
            });
        }
        if (!_moveController.isAnimating) {
            _moveController.value = _dragExtent.abs() / _overallDragAxisExtent;
        }
    }

    void _updateMoveAnimation() {
        final double end = _dragExtent.sign;
        _moveAnimation = new Tween<Offset>(
            begin: Offset.zero,
            end: _directionIsXAxis
                ? new Offset(end, widget.crossAxisEndOffset)
                : new Offset(widget.crossAxisEndOffset, end),
        ).animate(_moveController);
    }

    _FlingGestureKind _describeFlingGesture(Velocity velocity) {
        assert(widget.direction != null);
        if (_dragExtent == 0.0) {
            return _FlingGestureKind.none;
        }
        final double vx = velocity.pixelsPerSecond.dx;
        final double vy = velocity.pixelsPerSecond.dy;
        DismissDirection flingDirection;
        if (_directionIsXAxis) {
            if (vx.abs() - vy.abs() < _kMinFlingVelocityDelta || vx.abs() < _kMinFlingVelocity)
                return _FlingGestureKind.none;
            assert(vx != 0.0);
            flingDirection = _extentToDirection(vx);
        } else {
            if (vy.abs() - vx.abs() < _kMinFlingVelocityDelta || vy.abs() < _kMinFlingVelocity)
                return _FlingGestureKind.none;
            assert(vy != 0.0);
            flingDirection = _extentToDirection(vy);
        }
        assert(_dismissDirection != null);
        if (flingDirection == _dismissDirection)
            return _FlingGestureKind.forward;
        return _FlingGestureKind.reverse;
    }

    void _handleDragEnd(DragEndDetails details) {
        print('end-----');
        print('|||||   $_isActive   ${_moveController.isAnimating}');
        if (!_isActive || _moveController.isAnimating) {

            if(_moveController.isAnimating) {
                print('++++++++');
                    _moveController.value = .0;//widget.menusWidth / _overallDragAxisExtent;
                    _moveController.stop(canceled: true);
                    return;
            }
            return;
        }
        //TODO
        if(this._menuFilter()) {
            return;
        }
        //TODO
        _dragUnderway = false;
        if (_moveController.isCompleted) {
            _startResizeAnimation();
          return;
        }

        final double flingVelocity = _directionIsXAxis ? details.velocity.pixelsPerSecond.dx : details.velocity.pixelsPerSecond.dy;
        switch (_describeFlingGesture(details.velocity)) {
            case _FlingGestureKind.forward:
                print('######   forward');
                assert(_dragExtent != 0.0);
                assert(!_moveController.isDismissed);
                if ((widget.dismissThresholds[_dismissDirection] ?? _kDismissThreshold) >= 1.0) {
                    _moveController.reverse();
                    break;
                }
                _dragExtent = flingVelocity.sign;
                _moveController.fling(velocity: flingVelocity.abs() * _kFlingVelocityScale);
                break;
            case _FlingGestureKind.reverse:
                print('######   reverse');
                assert(_dragExtent != 0.0);
                assert(!_moveController.isDismissed);
                _dragExtent = flingVelocity.sign;
                _moveController.fling(velocity: -flingVelocity.abs() * _kFlingVelocityScale);
                break;
            case _FlingGestureKind.none:
                print('######   none');
                if (!_moveController.isDismissed) { // we already know it's not completed, we check that above
                    var edge = (widget.dismissThresholds[_dismissDirection] ?? _kDismissThreshold);
                    var dd = _dragExtent / widget.menusWidth;
                    print('>>>   $dd  ${_moveController.value}   menusWidth: ${widget.menusWidth} , widgetWidth: ${context.size.width}');
                    GlobalObjectKey gg = widget.secondaryBackground.key as GlobalObjectKey;
                    print('>>>   ${widget.secondaryBackground?.key}   $gg  ${gg?.currentContext?.size}  ${_rightMenuBC?.size}');
                    if(dd.abs() > .5) {

                        double to = (widget.menusWidth - _dragExtent.abs()) / (context.size.width - _dragExtent.abs());
                        to = widget.menusWidth / (context.size.width);
                        _moveController.animateTo(to);
                    }else {
                        _moveController.reverse();
                    }
//                    if (_moveController.value > edge) {
//                        _moveController.forward();
//                    } else {
//                        _moveController.reverse();
//                    }
                }
                break;
        }
    }

    void _handleDismissStatusChanged(AnimationStatus status) {
        if (status == AnimationStatus.completed && !_dragUnderway)
            _startResizeAnimation();
        updateKeepAlive();
    }

    void _startResizeAnimation() {
        assert(_moveController != null);
        assert(_moveController.isCompleted);
        assert(_resizeController == null);
        assert(_sizePriorToCollapse == null);
        if (widget.resizeDuration == null) {
            if (widget.onDismissed != null) {
                final DismissDirection direction = _dismissDirection;
                assert(direction != null);
                widget.onDismissed(direction);
            }
        } else {
//            _resizeController = new AnimationController(duration: widget.resizeDuration, vsync: this)
//                ..addListener(_handleResizeProgressChanged)
//                ..addStatusListener((AnimationStatus status) => updateKeepAlive())
//                ..addStatusListener((AnimationStatus status) {
//                    print('&&&&&&&&&&&   ${status.index}');
//                })
//            ;
//            _resizeController.forward();
//            setState(() {
//                _sizePriorToCollapse = context.size;
//                _resizeAnimation = new Tween<double>(
//                    begin: 1.0,
//                    end: 0.0
//                ).animate(new CurvedAnimation(
//                    parent: _resizeController,
//                    curve: _kResizeTimeCurve
//                ))..addListener(() {
//                    print(')))))))  ${_resizeController.value}  ${this._menuFilter()}  $_sizePriorToCollapse');
//                });
//            });
        }
    }

    void _handleResizeProgressChanged() {
        if (_resizeController.isCompleted) {
            if (widget.onDismissed != null) {
                final DismissDirection direction = _dismissDirection;
                assert(direction != null);
                widget.onDismissed(direction);
            }
        } else {
            if (widget.onResize != null) {
                widget.onResize();
            }
        }
    }

    bool _menuFilter() {
        if(widget.menusWidth != null && widget.menusWidth > 0) {
            if(_dragExtent.abs() >= widget.menusWidth) {
                return true;
            }
        }

        return false;
    }

    BuildContext _rightMenuBC;
    @override
    Widget build(BuildContext context) {
        super.build(context); // See AutomaticKeepAliveClientMixin.

        assert(!_directionIsXAxis || debugCheckHasDirectionality(context));

        Widget background = widget.background;
        if (widget.secondaryBackground != null) {
            final DismissDirection direction = _dismissDirection;
            if (direction == DismissDirection.endToStart || direction == DismissDirection.up)
                background = widget.secondaryBackground;
        }

        if (_resizeAnimation != null) {
          // we've been dragged aside, and are now resizing.
            assert(() {
                if (_resizeAnimation.status != AnimationStatus.forward) {
                    assert(_resizeAnimation.status == AnimationStatus.completed);
                    throw new FlutterError(
                        'A dismissed Dismissible widget is still part of the tree.\n'
                            'Make sure to implement the onDismissed handler and to immediately remove the Dismissible\n'
                            'widget from the application once that handler has fired.'
                    );
                }
                return true;
            }());

            return new SizeTransition(
                sizeFactor: _resizeAnimation,
                axis: _directionIsXAxis ? Axis.vertical : Axis.horizontal,
                child: new SizedBox(
                    width: _sizePriorToCollapse.width,
                    height: _sizePriorToCollapse.height,
                    child: background
                )
            );
        }

        Widget content = new SlideTransition(
            position: _moveAnimation,
            child: widget.child
        );

//        if (background != null) {
//            final List<Widget> children = <Widget>[];
//
//            if (!_moveAnimation.isDismissed) {
//                children.add(new Positioned.fill(
//                    child: new ClipRect(
//                        clipper: new _DismissibleClipper(
//                          axis: _directionIsXAxis ? Axis.horizontal : Axis.vertical,
//                          moveAnimation: _moveAnimation,
//                        ),
//                        child: background
//                    )
//                ));
//            }
//
//            children.add(content);
//            content = new Stack(children: children);
//        }

        final List<Widget> children = this._appendMenus([], background);

        children.add(content);
        content = new Stack(children: children);

        // We are not resizing but we may be being dragging in widget.direction.
        return new GestureDetector(
            onHorizontalDragStart: _directionIsXAxis ? _handleDragStart : null,
            onHorizontalDragUpdate: _directionIsXAxis ? _handleDragUpdate : null,
            onHorizontalDragEnd: _directionIsXAxis ? _handleDragEnd : null,
            onVerticalDragStart: _directionIsXAxis ? null : _handleDragStart,
            onVerticalDragUpdate: _directionIsXAxis ? null : _handleDragUpdate,
            onVerticalDragEnd: _directionIsXAxis ? null : _handleDragEnd,
            behavior: HitTestBehavior.opaque,
            child: content
        );
    }

    List<Widget> _appendMenus(List<Widget> children, Widget menus) {
        children = children ?? new List();
        switch(widget.direction) {
            case DismissDirection.horizontal: {

                break;
            }
            case DismissDirection.endToStart: {
                children.add(
                    new Positioned.fill(
                        child: new Align(
                            child: new LayoutBuilder(builder: (context, cons) {
                                _rightMenuBC = context;
                                return menus;
                            },),
                            alignment: Alignment.centerRight,
                        ),
                    ),
                );
                break;
            }
        }

        return children;
    }
}