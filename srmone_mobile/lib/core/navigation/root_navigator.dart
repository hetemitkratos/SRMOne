// lib/core/navigation/root_navigator.dart
// The app's root navigator key, shared by GoRouter and work that outlives the
// screen that started it (e.g. a Student Portal CAPTCHA prompt that appears
// after sign-in has already moved on to the dashboard).

import 'package:flutter/widgets.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
