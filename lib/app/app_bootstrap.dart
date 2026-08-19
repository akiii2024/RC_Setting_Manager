import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';
import 'app.dart';
import 'app_error_view.dart';

/// Initializes framework error handling and mounts the application root once.
///
/// Dependency initialization and retries are owned by [ApplicationBootstrap],
/// so a retry never calls [runApp] again.
Future<void> bootstrapApplication() {
  WidgetsFlutterBinding.ensureInitialized();

  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previousFlutterErrorHandler != null) {
      previousFlutterErrorHandler(details);
    } else {
      FlutterError.presentError(details);
    }
    debugLog('Flutter Error: ${details.exception}');
    debugLog('Stack trace: ${details.stack}');
  };
  final platformDispatcher = PlatformDispatcher.instance;
  final previousPlatformErrorHandler = platformDispatcher.onError;
  platformDispatcher.onError = (error, stackTrace) {
    debugLog('Uncaught asynchronous error: $error');
    debugLog('Stack trace: $stackTrace');
    return previousPlatformErrorHandler?.call(error, stackTrace) ?? false;
  };
  ErrorWidget.builder = AppErrorView.build;

  runApp(const ApplicationBootstrap());
  return Future<void>.value();
}

/// A dependency set created for one bootstrap generation.
///
/// This interface is public only so widget tests can supply a lightweight
/// session without initializing platform services.
@visibleForTesting
abstract interface class ApplicationBootstrapSession {
  Widget build(VoidCallback onRetry);

  void dispose();
}

@visibleForTesting
typedef ApplicationBootstrapSessionFactory = Future<ApplicationBootstrapSession>
    Function();

/// Stateful root that replaces only the dependency subtree when retrying.
class ApplicationBootstrap extends StatefulWidget {
  const ApplicationBootstrap({
    super.key,
    this.sessionFactory,
  });

  @visibleForTesting
  final ApplicationBootstrapSessionFactory? sessionFactory;

  @override
  State<ApplicationBootstrap> createState() => _ApplicationBootstrapState();
}

class _ApplicationBootstrapState extends State<ApplicationBootstrap> {
  static const Key _progressIndicatorKey =
      Key('application-bootstrap-progress');

  ApplicationBootstrapSession? _session;
  ApplicationBootstrapSession? _renderedSession;
  ApplicationBootstrapSession? _retiringSession;
  int? _retiringGeneration;
  Object? _initializationError;
  StackTrace? _initializationStackTrace;
  int? _sessionGeneration;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _initialize(notify: false);
  }

  void _initialize({bool notify = true}) {
    final generation = ++_generation;
    final previousSession = _session;
    final previousSessionWasRendered =
        previousSession != null && identical(previousSession, _renderedSession);

    void resetState() {
      _session = null;
      _sessionGeneration = null;
      _initializationError = null;
      _initializationStackTrace = null;
    }

    if (notify) {
      setState(resetState);
    } else {
      resetState();
    }

    if (previousSessionWasRendered) {
      _retiringSession = previousSession;
      _retiringGeneration = generation;
      return;
    }

    previousSession?.dispose();
    _startInitialization(generation);
  }

  void _startInitialization(int generation) {
    if (!mounted || generation != _generation) {
      return;
    }
    final factory = widget.sessionFactory ?? _createProviderSession;
    unawaited(
      Future<ApplicationBootstrapSession>.sync(factory).then(
        (newSession) {
          if (!mounted || generation != _generation) {
            newSession.dispose();
            return;
          }

          setState(() {
            _session = newSession;
            _sessionGeneration = generation;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted || generation != _generation) {
            return;
          }

          debugLog('Application initialization failed: $error');
          debugLog('Stack trace: $stackTrace');
          setState(() {
            _initializationError = error;
            _initializationStackTrace = stackTrace;
          });
        },
      ),
    );
  }

  void _handleSessionHostDisposed(
    ApplicationBootstrapSession disposedSession,
  ) {
    if (!identical(_retiringSession, disposedSession)) {
      return;
    }

    final generation = _retiringGeneration;
    _retiringSession = null;
    _retiringGeneration = null;
    if (generation == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) {
        _startInitialization(generation);
      }
    });
  }

  @override
  void dispose() {
    ++_generation;
    final unrenderedSession = _session;
    if (unrenderedSession != null &&
        !identical(unrenderedSession, _renderedSession)) {
      unrenderedSession.dispose();
    }
    _session = null;
    _retiringSession = null;
    _retiringGeneration = null;
    super.dispose();
  }

  void _retrySession(
    ApplicationBootstrapSession session,
    int sessionGeneration,
  ) {
    if (!mounted ||
        !identical(_session, session) ||
        _generation != sessionGeneration) {
      return;
    }
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) {
      final sessionGeneration = _sessionGeneration!;
      _renderedSession = session;
      return _ApplicationSessionHost(
        key: ObjectKey(session),
        session: session,
        onRetry: () => _retrySession(session, sessionGeneration),
        onDisposed: () => _handleSessionHostDisposed(session),
      );
    }

    _renderedSession = null;
    final error = _initializationError;
    if (error != null) {
      final errorGeneration = _generation;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AppErrorView.initializationFailure(
          error: error,
          stackTrace: _initializationStackTrace ?? StackTrace.empty,
          onRetry: () {
            if (mounted &&
                _generation == errorGeneration &&
                _initializationError != null) {
              _initialize();
            }
          },
        ),
      );
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: _progressIndicatorKey),
        ),
      ),
    );
  }
}

class _ApplicationSessionHost extends StatefulWidget {
  const _ApplicationSessionHost({
    super.key,
    required this.session,
    required this.onRetry,
    required this.onDisposed,
  });

  final ApplicationBootstrapSession session;
  final VoidCallback onRetry;
  final VoidCallback onDisposed;

  @override
  State<_ApplicationSessionHost> createState() =>
      _ApplicationSessionHostState();
}

class _ApplicationSessionHostState extends State<_ApplicationSessionHost> {
  @override
  Widget build(BuildContext context) => widget.session.build(widget.onRetry);

  @override
  void dispose() {
    try {
      widget.session.dispose();
    } finally {
      widget.onDisposed();
      super.dispose();
    }
  }
}

Future<ApplicationBootstrapSession> _createProviderSession() async {
  // This release always starts offline. In particular, do not read or
  // overwrite a previously stored online_mode preference here.
  final appModeProvider = AppModeProvider(
    preferredOnline: false,
    isFirebaseReady: false,
    onlineCapabilityEnabled: false,
  );
  ThemeProvider? themeProvider;

  try {
    themeProvider = await ThemeProvider.create();
    final settingsProvider = await SettingsProvider.create(
      appModeProvider: appModeProvider,
    );
    return _ProviderApplicationBootstrapSession(
      appModeProvider: appModeProvider,
      themeProvider: themeProvider,
      settingsProvider: settingsProvider,
    );
  } catch (_) {
    themeProvider?.dispose();
    appModeProvider.dispose();
    rethrow;
  }
}

class _ProviderApplicationBootstrapSession
    implements ApplicationBootstrapSession {
  _ProviderApplicationBootstrapSession({
    required this.appModeProvider,
    required this.themeProvider,
    required this.settingsProvider,
  });

  final AppModeProvider appModeProvider;
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;
  var _isDisposed = false;

  @override
  Widget build(VoidCallback onRetry) {
    assert(!_isDisposed, 'A disposed bootstrap session cannot be built.');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: appModeProvider,
        ),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
        ),
      ],
      child: const ApplicationAuthScope(
        child: MyApp(),
      ),
    );
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    settingsProvider.dispose();
    themeProvider.dispose();
    appModeProvider.dispose();
  }
}

@visibleForTesting
typedef AuthServiceFactory = AuthService Function();

/// Keeps the inherited provider type stable while online authentication is
/// enabled or disabled, so switching mode does not replace the app navigator.
@visibleForTesting
class ApplicationAuthScope extends StatefulWidget {
  const ApplicationAuthScope({
    super.key,
    required this.child,
    this.authServiceFactory,
  });

  final Widget child;
  final AuthServiceFactory? authServiceFactory;

  @override
  State<ApplicationAuthScope> createState() => _ApplicationAuthScopeState();
}

class _ApplicationAuthScopeState extends State<ApplicationAuthScope> {
  AuthService? _authService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onlineActive = Provider.of<AppModeProvider>(context).isOnlineActive;
    if (onlineActive) {
      _authService ??= (widget.authServiceFactory ?? AuthService.new)();
      return;
    }

    final previousService = _authService;
    _authService = null;
    previousService?.dispose();
  }

  @override
  void didUpdateWidget(covariant ApplicationAuthScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authServiceFactory != widget.authServiceFactory &&
        _authService != null) {
      _authService!.dispose();
      _authService = (widget.authServiceFactory ?? AuthService.new)();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<AuthService?>.value(
      value: _authService,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _authService?.dispose();
    _authService = null;
    super.dispose();
  }
}
