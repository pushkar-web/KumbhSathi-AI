import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/settings/screens/ai_settings_screen.dart';
import '../../features/shell/portal_home_screen.dart';
import '../../providers/auth_provider.dart';

/// Route name/path constants.
abstract final class Routes {
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String home = '/';
  static const String aiSettings = '/ai-settings';
}

/// Bridges a Riverpod [StateNotifierProvider] to a [Listenable] so GoRouter
/// re-evaluates its redirect whenever auth state changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // Wait for bootstrap to resolve before redirecting.
      if (auth.status == AuthStatus.unknown) return null;

      final loggedIn = auth.status == AuthStatus.authenticated;
      final atAuthScreen =
          loc == Routes.login || loc == Routes.register || loc == Routes.otp;

      if (!loggedIn && !atAuthScreen) return Routes.login;
      if (loggedIn && atAuthScreen) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (_, state) => LoginScreen(
          registeredPhone: state.extra as String?,
        ),
      ),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) => OtpScreen(
          phone: state.extra as String? ?? '+91 98765 43210',
        ),
      ),
      GoRoute(path: Routes.home, builder: (_, __) => const PortalHomeScreen()),
      GoRoute(
        path: Routes.aiSettings,
        builder: (_, __) => const AiSettingsScreen(),
      ),
    ],
  );
});
