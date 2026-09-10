import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tensorflow_demo/screens/auth/login_screen.dart';
import 'package:tensorflow_demo/screens/home/home_screen.dart';
import 'package:tensorflow_demo/screens/home/home_screen_store.dart';
import 'package:tensorflow_demo/screens/live_object_detection/live_object_detection_screen.dart';
import 'package:tensorflow_demo/screens/photo_analyzed/photo_analyze_screen.dart';
import 'package:tensorflow_demo/screens/splash/splash_screen.dart';
import 'package:tensorflow_demo/values/app_routes.dart';

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    Route<dynamic> getRoute({
      required Widget widget,
      bool fullscreenDialog = false,
    }) {
      return MaterialPageRoute<void>(
        builder: (context) => widget,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      );
    }

    switch (settings.name) {
      case AppRoutes.splashScreen:
        return getRoute(widget: const SplashScreen());
      case AppRoutes.loginScreen:
        return getRoute(widget: const LoginScreen());
      case AppRoutes.homeScreen:
        return getRoute(
          widget: Provider(
            create: (_) => HomeScreenStore()..initialize(),
            child: const HomeScreen(),
          ),
        );
      case AppRoutes.photoAnalyzedScreen:
        final rawArgs = settings.arguments;
        Uint8List? imageBytes;
        if (rawArgs is Uint8List) {
          imageBytes = rawArgs;
        } else if (rawArgs is List<int>) {
          imageBytes = Uint8List.fromList(rawArgs);
        }

        return getRoute(
          widget: (imageBytes == null || imageBytes.isEmpty)
              ? const Scaffold(
                  body: Center(
                    child: Text('Invalid image data'),
                  ),
                )
              : PhotoAnalyzedScreen(
                  imageBytes: imageBytes,
                ),
        );
      case AppRoutes.cameraScreen:
        return getRoute(widget: const LiveObjectDetectionScreen());

      /// An invalid route. User shouldn't see this, it's for debugging purpose
      /// only.
      default:
        return getRoute(widget: const Placeholder());
    }
  }
}
