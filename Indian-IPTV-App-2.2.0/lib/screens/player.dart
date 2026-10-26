import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import '../model/channel.dart';

class Player extends StatefulWidget {
  final Channel? channel;
  final String? url;
  final List<Channel>? playlist;
  final int initialIndex;

  const Player({
    Key? key,
    this.channel,
    this.url,
    this.playlist,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? videoPlayerController;
  ChewieController? chewieController;
  bool _isLoading = true;
  bool _channelNotFound = false;
  late int _currentIndex;
  final FocusNode _playerFocusNode = FocusNode();

  Channel get _activeChannel {
    if (widget.playlist != null &&
        widget.playlist!.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < widget.playlist!.length) {
      return widget.playlist![_currentIndex];
    }
    if (widget.channel != null) {
      return widget.channel!;
    }
    return Channel(
      name: 'Live Stream',
      logoUrl: 'assets/images/tv-icon.png',
      streamUrl: widget.url ?? '',
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadCurrentChannel();
  }

  Future<void> _loadCurrentChannel() async {
    setState(() {
      _isLoading = true;
      _channelNotFound = false;
    });

    final oldVideo = videoPlayerController;
    final oldChewie = chewieController;
    videoPlayerController = null;
    chewieController = null;
    await oldVideo?.dispose();
    oldChewie?.dispose();

    final current = _activeChannel;
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(current.streamUrl));
    videoPlayerController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      chewieController = ChewieController(
        videoPlayerController: controller,
        autoInitialize: true,
        isLive: true,
        autoPlay: true,
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        showOptions: false,
      );
      controller.addListener(() {
        if (controller.value.isPlaying) {
          Wakelock.enable();
        } else {
          Wakelock.disable();
        }
      });
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _channelNotFound = true;
      });
    }
  }

  void _changeChannel(int delta) {
    if (widget.playlist == null || widget.playlist!.length <= 1) return;
    setState(() {
      _currentIndex =
          (_currentIndex + delta + widget.playlist!.length) %
              widget.playlist!.length;
    });
    _loadCurrentChannel();
  }

  @override
  void dispose() {
    Wakelock.disable();
    videoPlayerController?.dispose();
    chewieController?.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _activeChannel;
    return KeyboardListener(
      focusNode: _playerFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.channelUp ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _changeChannel(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.channelDown ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _changeChannel(1);
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
            if (videoPlayerController != null &&
                videoPlayerController!.value.isInitialized) {
              if (videoPlayerController!.value.isPlaying) {
                videoPlayerController!.pause();
              } else {
                videoPlayerController!.play();
              }
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('${current.name} • ${current.category}'),
          actions: [
            if (widget.playlist != null && widget.playlist!.length > 1) ...[
              IconButton(
                icon: const Icon(Icons.skip_previous),
                tooltip: 'Previous Channel (Up)',
                onPressed: () => _changeChannel(-1),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                tooltip: 'Next Channel (Down)',
                onPressed: () => _changeChannel(1),
              ),
            ],
          ],
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _channelNotFound || chewieController == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.amberAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Channel not available right now',
                          style: TextStyle(fontSize: 20.0, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadCurrentChannel,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Stream'),
                        ),
                      ],
                    )
                  : Chewie(controller: chewieController!),
        ),
      ),
    );
  }
}
