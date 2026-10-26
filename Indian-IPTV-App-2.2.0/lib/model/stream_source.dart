import 'package:flutter/material.dart';

class StreamSource {
  final String name;
  final String streamUrl;
  final IconData icon;

  const StreamSource({
    required this.name,
    required this.streamUrl,
    this.icon = Icons.live_tv,
  });
}
