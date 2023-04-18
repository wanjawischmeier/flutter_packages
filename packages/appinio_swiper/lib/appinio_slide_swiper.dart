import 'appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'size_provider.dart';
export 'size_provider.dart';

class AppinioSlideSwiper extends AppinioSwiper {
  /// how easily the sliding gesture is detected
  final double slideSensitivity;

  /// set to true if the angle shouldn't change depending on the grab point
  final bool absoluteAngle;

  /// offset the background card vertically
  final double offset;

  /// function that gets called when the user slides vertically
  final OnSlide? onSlide;

  const AppinioSlideSwiper({
    Key? key,
    required cardsBuilder,
    required cardsCount,
    controller,
    padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
    duration = const Duration(milliseconds: 200),
    maxAngle = 30,
    threshold = 50,
    isDisabled = false,
    loop = false,
    allowUnswipe = true,
    unlimitedUnswipe = false,
    onTapDisabled,
    onSwipe,
    onEnd,
    unswipe,
    direction = AppinioSwiperDirection.right,
    this.slideSensitivity = 0.5,
    this.absoluteAngle = false,
    this.offset = 50,
    this.onSlide,
  }) : super(
            key: key,
            cardsBuilder: cardsBuilder,
            cardsCount: cardsCount,
            controller: controller,
            padding: padding,
            duration: duration,
            maxAngle: maxAngle,
            threshold: threshold,
            isDisabled: isDisabled,
            loop: loop,
            allowUnswipe: allowUnswipe,
            unlimitedUnswipe: unlimitedUnswipe,
            onTapDisabled: onTapDisabled,
            onSwipe: onSwipe,
            onEnd: onEnd,
            unswipe: unswipe,
            direction: direction);

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
  int currentIndex = 0;

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
  final Map<int, AppinioSwiperDirection> _swiperMemo =
      {}; //keep track of the swiped items to unswipe from the same direction

  bool _unSwiped =
      false; // set this to true when user swipe the card and false when they unswipe to make sure they unswipe only once

  bool _isUnswiping = false;
  int _swipedDirectionHorizontal = 0; //-1 bottom, 1 top

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
            if (currentIndex < widget.cardsCount) {
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
            if (currentIndex < widget.cardsCount) {
              _left = -1;
              _swipeHorizontal(context);
              _animationController.forward();
            }
          }
        })
        //swipe widget right from the outside
        ..addListener(() {
          if (widget.controller!.state == AppinioSwiperState.swipeRight) {
            if (currentIndex < widget.cardsCount) {
              _left = widget.threshold + 1;
              _swipeHorizontal(context);
              _animationController.forward();
            }
          }
        })
        //unswipe widget from the outside
        ..addListener(() {
          if (!widget.unlimitedUnswipe && _unSwiped) return;
          if (widget.controller!.state == AppinioSwiperState.unswipe) {
            if (widget.allowUnswipe) {
              if (!_isUnswiping) {
                if (currentIndex > 0) {
                  _unswipe();
                  widget.unswipe?.call(true);
                  _animationController.forward();
                } else {
                  widget.unswipe?.call(false);
                }
              }
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
              _swiperMemo[currentIndex] = (_swipedDirectionHorizontal == 1
                  ? AppinioSwiperDirection.right
                  : AppinioSwiperDirection.left);
              _swipedDirectionHorizontal = 0;
              _swipeType = 4;
              _left = 0;
              _top = 0;
              _total = 0;
              _angle = 0;

              if (widget.loop) {
                if (currentIndex < widget.cardsCount - 1) {
                  currentIndex++;
                } else {
                  currentIndex = 0;
                }
              } else {
                currentIndex++;
              }
              widget.onSwipe?.call(currentIndex, detectedDirection);
              if (currentIndex == widget.cardsCount) {
                widget.onEnd?.call();
              }

              _differenceAnimation = Tween<double>(begin: 0, end: widget.offset)
                  .animate(_animationController);
              _backgroundScaleAnimation =
                  Tween<double>(begin: _backgroundScale, end: 0.9)
                      .animate(_animationController);
              _animationController.forward();
              break;
            case 2:
              _isUnswiping = false;
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
    super.dispose();
    _animationController.dispose();
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
                    if (widget.loop || currentIndex < widget.cardsCount - 1)
                      _backgroundItem(constraints),
                    if (currentIndex < widget.cardsCount)
                      _foregroundItem(constraints)
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
        child: Container(constraints: constraints, child: _getCard(false)),
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
                  child: _getCard(true),
                )),
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

                  if (widget.onSlide?.call(currentIndex, _slide) ?? false) {
                    _foregroundScaleAnimation =
                        Tween<double>(begin: 1.025, end: 1)
                            .animate(_animationController);
                    _animationController.forward();
                  }
                }
              } else if (_top.abs() > widget.threshold &&
                  _top.abs() * widget.slideSensitivity > _left.abs()) {
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

  Widget _getCard(bool foreground) {
    return widget.cardsBuilder(
        context,
        foreground ? currentIndex : (currentIndex + 1) % widget.cardsCount,
        foreground);
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
    _unSwiped = false;
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
      _swipedDirectionHorizontal = 1;
      detectedDirection = AppinioSwiperDirection.right;
    } else {
      _swipedDirectionHorizontal = -1;
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

  //unswipe the card: brings back the last card that was swiped away
  void _unswipe() {
    _unSwiped = true;
    _isUnswiping = true;
    if (widget.loop) {
      if (currentIndex == 0) {
        currentIndex = widget.cardsCount - 1;
      } else {
        currentIndex--;
      }
    } else {
      if (currentIndex > 0) {
        currentIndex--;
      }
    }
    _swipeType = 2;
    //unSwipe horizontal
    if (_swiperMemo[currentIndex] == AppinioSwiperDirection.right ||
        _swiperMemo[currentIndex] == AppinioSwiperDirection.left) {
      _unSwipeLeftAnimation = Tween<double>(
        begin: (_swiperMemo[currentIndex] == AppinioSwiperDirection.right)
            ? MediaQuery.of(context).size.width
            : -MediaQuery.of(context).size.width,
        end: 0,
      ).animate(_animationController);
      _unSwipeTopAnimation = Tween<double>(
        begin: (_swiperMemo[currentIndex] == AppinioSwiperDirection.top)
            ? -MediaQuery.of(context).size.height / 4
            : MediaQuery.of(context).size.height / 4,
        end: 0,
      ).animate(_animationController);
      _backgroundScaleAnimation = Tween<double>(
        begin: 1.0,
        end: _backgroundScale,
      ).animate(_animationController);
      _differenceAnimation = Tween<double>(
        begin: 0,
        end: _difference,
      ).animate(_animationController);
    }
    //unSwipe vertical
    if (_swiperMemo[currentIndex] == AppinioSwiperDirection.top ||
        _swiperMemo[currentIndex] == AppinioSwiperDirection.bottom) {
      _unSwipeLeftAnimation = Tween<double>(
        begin: (_swiperMemo[currentIndex] == AppinioSwiperDirection.right)
            ? MediaQuery.of(context).size.width / 4
            : -MediaQuery.of(context).size.width / 4,
        end: 0,
      ).animate(_animationController);
      _unSwipeTopAnimation = Tween<double>(
        begin: (_swiperMemo[currentIndex] == AppinioSwiperDirection.top)
            ? -MediaQuery.of(context).size.height
            : MediaQuery.of(context).size.height,
        end: 0,
      ).animate(_animationController);
      _backgroundScaleAnimation = Tween<double>(
        begin: 1.0,
        end: _backgroundScale,
      ).animate(_animationController);
      _differenceAnimation = Tween<double>(
        begin: 0,
        end: _difference,
      ).animate(_animationController);
    }

    setState(() {});
  }
}
