import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const String _channelName = 'social_sport_ladder/location_button';
const String _viewType = 'social_sport_ladder/location_button_view';

/// The system location button only exists in the Android app.
bool get locationButtonSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Hosts the androidx LocationButton. On Android 17+ it grants session-scoped
/// precise location; on older versions the library shows the normal prompt.
class SystemLocationButton extends StatefulWidget {
  final double width;
  final double height;
  final void Function(bool granted) onPermissionResult;

  const SystemLocationButton({
    super.key,
    required this.width,
    required this.height,
    required this.onPermissionResult,
  });

  @override
  State<SystemLocationButton> createState() => _SystemLocationButtonState();
}

class _SystemLocationButtonState extends State<SystemLocationButton> {
  final MethodChannel _channel = const MethodChannel(_channelName);

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionResult') {
        widget.onPermissionResult(call.arguments == true);
      } else if (call.method == 'onError' && kDebugMode) {
        debugPrint('LocationButton error: ${call.arguments}');
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!locationButtonSupported) return const SizedBox.shrink();
    return SizedBox(
      width: widget.width,
      height: widget.height,
      // Hybrid composition is required: the button renders in a SurfaceView.
      child: PlatformViewLink(
        viewType: _viewType,
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _viewType,
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
        },
      ),
    );
  }
}
