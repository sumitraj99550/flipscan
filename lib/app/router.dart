import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/review/review_screen.dart';
import '../features/file_manager/document_list_screen.dart';
import '../features/file_manager/document_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/video/video_scan_screen.dart';
import '../models/scanned_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/video-scan',
        builder: (context, state) => const VideoScanScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) {
          final pages = state.extra as List<ScannedPage>? ?? [];
          return ReviewScreen(pages: pages);
        },
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentListScreen(),
      ),
      GoRoute(
        path: '/document/:id',
        builder: (context, state) {
          final docId = state.pathParameters['id']!;
          return DocumentDetailScreen(documentId: docId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
