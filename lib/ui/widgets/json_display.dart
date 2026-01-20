import 'dart:convert';
import 'package:flutter/material.dart';

import 'json_highlighter.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
}

class JsonDisplay extends StatefulWidget {
  static Interpreter? interpreter;
  static Set<String> highlightKeys = {};

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> interpret;
  final bool strikethrough;
  final Interpreter? instanceInterpreter;

  JsonDisplay(this.subject,
      {ValueNotifier<bool>? interpret, this.strikethrough = false, this.instanceInterpreter, super.key})
      : interpret = interpret ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  static const JsonEncoder encoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    // Basic interpretation: If interpreter is present, use it. Otherwise just use subject.
    dynamic interpreted = widget.subject;
    final activeInterpreter = widget.instanceInterpreter ?? JsonDisplay.interpreter;
    if (widget.interpret.value && activeInterpreter != null) {
      interpreted = activeInterpreter.interpret(widget.subject);
    }

    String display;
    try {
      display = encoder.convert(interpreted);
    } catch (e) {
      display = interpreted.toString();
    }

    TextStyle baseStyle = const TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ).copyWith(
      decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      color: widget.interpret.value ? Colors.green[900] : null,
    );

    List<TextSpan> spans = highlightJsonKeys(display, baseStyle,
        keysToHighlight: JsonDisplay.highlightKeys);

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(TextSpan(children: spans)),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: FloatingActionButton(
              heroTag: 'Interpret',
              mini: true, 
              tooltip: !widget.interpret.value
                  ? 'Raw JSON shown; click to interpret'
                  : 'Interpreted JSON shown; click to show raw',
              backgroundColor: Colors.white,
              child: Icon(Icons.transform,
                  color: widget.interpret.value ? Colors.green[900] : Colors.grey),
              onPressed: () {
                setState(() {
                  widget.interpret.value = !widget.interpret.value;
                });
              }),
        ),
      ],
    );
  }
}
