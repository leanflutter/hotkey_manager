import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HotKeyRecorder extends StatefulWidget {
  @override
  _HotKeyRecorderState createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends State<HotKeyRecorder> {
  ValueChanged<RawKeyEvent> _listener = (RawKeyEvent event) {};

  @override
  void initState() {
    RawKeyboard.instance.addListener(_listener);
    super.initState();
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
