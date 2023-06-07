import 'package:appinio_swiper/controllers.dart';
import 'package:appinio_swiper/enums.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'size_provider.dart';
export 'size_provider.dart';

typedef OnStartSlide = bool Function();

typedef OnSlide = bool Function(double gradient);

/// return true if the card should be recentered
typedef OnSwipe = bool Function(AppinioSwiperDirection direction);

typedef OnUnSwipe = void Function(bool unswiped);

class AppinioSlideSwiper extends StatefulWidget {
  /// controller to trigger unswipe action
  final AppinioSwiperController? controller;

  /// duration of every animation
  final Duration duration;

  /// padding of the swiper
  final EdgeInsetsGeometry padding;

  /// maximum angle the card reaches while swiping
  final double maxAngle;

  /// threshold from which the card is swiped away
  final int threshold;

  /// set to true if swiping should be disabled, exception: triggered from the outside
  final bool isDisabled;

  /// set to false if unswipe should be disabled
  final bool allowUnswipe;

  /// function that gets called with the boolean true when the last card gets unswiped and with the boolean false when there is no card to unswipe
  final OnUnSwipe? unswipe;

  /// direction in which the card gets swiped when triggered by controller, default set to right
  final AppinioSwiperDirection direction;

  /// how easily the sliding gesture is detected
  final double slideSensitivity;

  /// set to true if the angle shouldn't change depending on the grab point
  final bool absoluteAngle;

  /// offset the background card vertically
  final double offset;

  /// function to verify wether the user should be able to slide
  final OnStartSlide? onStartSlide;

  /// function that gets called when the user slides vertically
  final OnSlide? onSlide;

  /// function that gets called with the new index and detected swipe direction when the user swiped or swipe is triggered by controller
  final OnSwipe? onSwipe;

  /// function that gets called when there is no widget left to be swiped away
  final VoidCallback? onEnd;

  /// function that gets triggered when the swiper is disabled
  final VoidCallback? onTapDisabled;

  final Widget? Function(BuildContext) foregroundCardBuilder;

  final Widget? Function(BuildContext) backgroundCardBuilder;

  const AppinioSlideSwiper({
    Key? key,
    this.controller,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
    this.duration = const Duration(milliseconds: 200),
    this.maxAngle = 30,
    this.threshold = 50,
    this.isDisabled = false,
    this.allowUnswipe = true,
    this.onTapDisabled,
    this.onSwipe,
    this.onEnd,
    this.unswipe,
    this.direction = AppinioSwiperDirection.right,
    this.slideSensitivity = 0.5,
    this.absoluteAngle = false,
    this.offset = 50,
    this.onStartSlide,
    this.onSlide,
    required this.foregroundCardBuilder,
    required this.backgroundCardBuilder,
  }) : super(key: key);

  @override
  State createState() => _AppinioSlideSwiperState();
}

class _AppinioSlideSwiperState extends State<AppinioSlideSwiper>
    with SingleTickerProviderStateMixin {
  double _left = 0;
  double _top = 0;
  double _total = 0;
  double _angle = 0;
  double _maxAngle = 0;
  double _backgroundScale = 0.9;
  double _foregroundScale = 1;
  double _height = 0;
  double _slide = 1;

  int _swipeType = 0; // 1 = swipe, 2 = unswipe, 3 = goBack, 4 = resetting
  bool _sliding = false;
  bool _tapOnTop = false; //position of starting drag point on card
  late double _difference;

  late AnimationController _animationController;
  late Animation<double> _leftAnimation;
  late Animation<double> _topAnimation;
  late Animation<double> _backgroundScaleAnimation;
  late Animation<double> _foregroundScaleAnimation;
  late Animation<double> _differenceAnimation;
  late Animation<double> _unSwipeLeftAnimation;
  late Animation<double> _unSwipeTopAnimation;

  AppinioSwiperDirection detectedDirection = AppinioSwiperDirection.none;

  @override
  void initState() {
    super.initState();

    _difference = widget.offset;

    if (widget.controller != null) {
      widget.controller!
        //swipe widget from the outside
        ..addListener(() {
          if (widget.controller!.state == AppinioSwiperState.swipe) {
            if (true) {
              switch (widget.direction) {
                case AppinioSwiperDirection.right:
                  _swipeHorizontal(context);
                  break;
                case AppinioSwiperDirection.left:
                  _swipeHorizontal(context);
                  break;
                default:
                  break;
              }
              _animationController.forward();
            }
          }
        })
        //swipe widget left from the outside
        ..addListener(() {
          if (widget.controller!.state == AppinioSwiperState.swipeLeft) {
            if (true) {
              _left = -1;
              _swipeHorizontal(context);
              _animationController.forward();
            }
          }
        })
        //swipe widget right from the outside
        ..addListener(() {
          if (widget.controller!.state == AppinioSwiperState.swipeRight) {
            if (true) {
              _left = widget.threshold + 1;
              _swipeHorizontal(context);
              _animationController.forward();
            }
          }
        });
    }

    if (widget.maxAngle > 0) {
      _maxAngle = widget.maxAngle * (pi / 180);
    }

    _animationController =
        AnimationController(duration: widget.duration, vsync: this);
    _animationController.addListener(() {
      //when value of controller changes
      if (_animationController.status == AnimationStatus.forward) {
        setState(() {
          if (_sliding && _swipeType != 3) {
            _foregroundScale = _foregroundScaleAnimation.value;
          } else {
            _backgroundScale = _backgroundScaleAnimation.value;
            _difference = _differenceAnimation.value;

            if (_swipeType == 2) {
              _left = _unSwipeLeftAnimation.value;
              _top = _unSwipeTopAnimation.value;
            } else if (_swipeType != 4) {
              _left = _leftAnimation.value;
              _top = _topAnimation.value;
            }
          }
        });
      }
    });

    _animationController.addStatusListener((status) {
      //when status of controller changes
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationController.reset();

          switch (_swipeType) {
            case 1:
              _swipeType = 4;

              var recenter = widget.onSwipe?.call(detectedDirection) ?? true;
              if (recenter) {
                _left = 0;
                _top = 0;
                _total = 0;
                _angle = 0;
              }

              _differenceAnimation = Tween<double>(begin: 0, end: widget.offset)
                  .animate(_animationController);
              _backgroundScaleAnimation =
                  Tween<double>(begin: _backgroundScale, end: 0.9)
                      .animate(_animationController);
              _animationController.forward();
              break;
            default:
              _left = 0;
              _top = 0;
              _total = 0;
              _angle = 0;
              _backgroundScale = 0.9;
              _swipeType = 0;
              _difference = widget.offset;
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          padding: widget.padding,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    _backgroundItem(constraints),
                    _foregroundItem(constraints),
                  ]);
            },
          ),
        );
      },
    );
  }

  Widget _backgroundItem(BoxConstraints constraints) {
    return Positioned(
      top: _difference,
      left: 0,
      child: Transform.scale(
        scale: _backgroundScale,
        child: Container(
          constraints: constraints,
          child: widget.backgroundCardBuilder(context),
        ),
      ),
    );
  }

  Widget _foregroundItem(BoxConstraints constraints) {
    return Positioned(
      left: _left,
      top: _top,
      child: GestureDetector(
        child: Transform.scale(
          scale: _foregroundScale,
          child: Transform.rotate(
            angle: _angle,
            child: Container(
              constraints: constraints,
              child: SizeProvider(
                onChildSize: (p0) => _height = p0.height,
                child: Container(
                  child: widget.foregroundCardBuilder(context),
                ),
              ),
            ),
          ),
        ),
        onTap: () {
          if (widget.isDisabled) {
            widget.onTapDisabled?.call();
          }
        },
        onPanStart: (tapInfo) {
          if (!widget.isDisabled) {
            RenderBox renderBox = context.findRenderObject() as RenderBox;
            Offset position = renderBox.globalToLocal(tapInfo.globalPosition);

            if (position.dy < renderBox.size.height / 2) _tapOnTop = true;
          }
        },
        onPanUpdate: (tapInfo) {
          if (!widget.isDisabled) {
            setState(() {
              if (_sliding) {
                double gradient = 1 - (tapInfo.localPosition.dy / _height);

                if (gradient != _slide) {
                  _slide = gradient;

                  if (widget.onSlide?.call(_slide) ?? false) {
                    _foregroundScaleAnimation =
                        Tween<double>(begin: 1.025, end: 1)
                            .animate(_animationController);
                    _animationController.forward();
                  }
                }
              } else if (
                  // if enough vertical slide
                  _top.abs() > widget.threshold &&
                      // if more vertical than factor of horizontal slide
                      _top.abs() * widget.slideSensitivity > _left.abs() &&
                      // if slide is confirmed
                      (widget.onStartSlide?.call() ?? true)) {
                _sliding = true;
                _goBack(context);
                _animationController.forward();
              } else {
                _left += tapInfo.delta.dx;
                _top += tapInfo.delta.dy;
              }

              _total = _left + _top;
              _calculateAngle();
              _calculateScale();
              _calculateDifference();
            });
          }
        },
        onPanEnd: (tapInfo) {
          if (!widget.isDisabled) {
            _tapOnTop = false;
            _sliding = false;
            _onEndAnimation();
            _animationController.forward();
          }
        },
      ),
    );
  }

  void _calculateAngle() {
    if (_angle <= _maxAngle && _angle >= -_maxAngle) {
      (_tapOnTop || widget.absoluteAngle)
          ? _angle = (_maxAngle / 100) * (_left / 10)
          : _angle = (_maxAngle / 100) * (_left / 10) * -1;
    }
  }

  void _calculateScale() {
    if (_backgroundScale <= 1.0 && _backgroundScale >= 0.9) {
      _backgroundScale =
          (_total > 0) ? 0.9 + (_total / 5000) : 0.9 + -1 * (_total / 5000);
    }
  }

  void _calculateDifference() {
    if (_difference >= 0 && _difference <= _difference) {
      _difference = (_total > 0)
          ? widget.offset - (_total / 10)
          : widget.offset + (_total / 10);
    }
  }

  void _onEndAnimation() {
    if (_left < -widget.threshold || _left > widget.threshold) {
      _swipeHorizontal(context);
    } else {
      _goBack(context);
    }
  }

  //moves the card away to the left or right
  void _swipeHorizontal(BuildContext context) {
    _slide = 1;
    setState(() {
      _swipeType = 1;
      _leftAnimation = Tween<double>(
        begin: _left,
        end: (_left == 0)
            ? (widget.direction == AppinioSwiperDirection.right)
                ? MediaQuery.of(context).size.width * 2
                : MediaQuery.of(context).size.width * -2
            : (_left > widget.threshold)
                ? MediaQuery.of(context).size.width * 2
                : MediaQuery.of(context).size.width * -2,
      ).animate(_animationController);
      _topAnimation = Tween<double>(
        begin: _top,
        end: _top + _top,
      ).animate(_animationController);
      _backgroundScaleAnimation = Tween<double>(
        begin: _backgroundScale,
        end: 1.0,
      ).animate(_animationController);
      _differenceAnimation = Tween<double>(
        begin: _difference,
        end: 0,
      ).animate(_animationController);
    });
    if (_left > widget.threshold ||
        _left == 0 && widget.direction == AppinioSwiperDirection.right) {
      detectedDirection = AppinioSwiperDirection.right;
    } else {
      detectedDirection = AppinioSwiperDirection.left;
    }
  }

  //moves the card back to starting position
  void _goBack(BuildContext context) {
    setState(() {
      _swipeType = 3;
      _leftAnimation = Tween<double>(
        begin: _left,
        end: 0,
      ).animate(_animationController);
      _topAnimation = Tween<double>(
        begin: _top,
        end: 0,
      ).animate(_animationController);
      _backgroundScaleAnimation = Tween<double>(
        begin: _backgroundScale,
        end: 0.9,
      ).animate(_animationController);
      _differenceAnimation = Tween<double>(
        begin: _difference,
        end: widget.offset,
      ).animate(_animationController);
    });
  }
}
