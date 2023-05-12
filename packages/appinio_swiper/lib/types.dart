import 'package:flutter/cupertino.dart';
import 'enums.dart';

typedef CardsBuilder = Widget Function(
    BuildContext context, int index, bool foreground);

typedef OnStartSlide = bool Function(int index);

typedef OnSlide = bool Function(int index, double gradient);

typedef OnSwipe = void Function(int index, AppinioSwiperDirection direction);

typedef OnUnSwipe = void Function(bool unswiped);
