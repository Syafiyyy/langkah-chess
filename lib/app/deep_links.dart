import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// The route for an incoming link, or null. Only `skak://join/CODE` is a
/// route; `skak://login-callback` belongs to Supabase Auth.
String? routeForLink(Uri uri) {
  if (uri.scheme != 'skak' || uri.host != 'join') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return Uri(
    path: '/online/join',
    queryParameters: {'code': segments.first},
  ).toString();
}

/// Opens invite links (including the one that started the app) in [router].
StreamSubscription<Uri> listenForDeepLinks(GoRouter router) {
  return AppLinks().uriLinkStream.listen((uri) {
    final route = routeForLink(uri);
    if (route != null) router.push(route);
  }, onError: (Object e) => debugPrint('Deep link failed: $e'));
}
