import 'package:flutter/material.dart';

class SizeProvider extends StatefulWidget {
  final Widget child;
  final Function(Size) onChildSize;

  const SizeProvider({Key? key, required this.onChildSize, required this.child})
      : super(key: key);
  @override
  State<SizeProvider> createState() => _SizeProviderState();
}

class _SizeProviderState extends State<SizeProvider> {
  @override
  void initState() {
    ///add size listener for first build
    _onResize();
    super.initState();
  }

  void _onResize() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (context.size is Size) {
        widget.onChildSize(context.size!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ///add size listener for every build uncomment the fallowing
    ///_onResize();
    return widget.child;
  }
}
