import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/settings_provider.dart';
import '../data/car_settings_definitions.dart';
import '../models/car_setting_definition.dart';
import '../models/car.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  int _welcomeTapCount = 0;
  DateTime? _lastWelcomeTap;
  bool _isStartingDemo = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_isSignUp) {
        await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<SettingsProvider>(context, listen: false).isEnglish
                    ? 'Account created successfully!'
                    : 'アカウントが正常に作成されました！',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<SettingsProvider>(context, listen: false).isEnglish
                    ? 'Signed in successfully!'
                    : 'サインインが完了しました！',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;

    print('Error message to parse: $error');

    if (error.contains('user-not-found')) {
      return isEnglish
          ? 'No user found for that email.'
          : 'そのメールアドレスのユーザーが見つかりません。';
    } else if (error.contains('wrong-password')) {
      return isEnglish ? 'Wrong password provided.' : 'パスワードが間違っています。';
    } else if (error.contains('email-already-in-use')) {
      return isEnglish
          ? 'The account already exists for that email.'
          : 'そのメールアドレスのアカウントは既に存在します。';
    } else if (error.contains('weak-password')) {
      return isEnglish ? 'The password provided is too weak.' : 'パスワードが弱すぎます。';
    } else if (error.contains('invalid-email')) {
      return isEnglish ? 'The email address is not valid.' : 'メールアドレスが無効です。';
    } else if (error.contains('operation-not-allowed')) {
      return isEnglish
          ? 'Email/password accounts are not enabled. Please contact support.'
          : 'メール/パスワードアカウントが有効になっていません。サポートにお問い合わせください。';
    } else if (error.contains('too-many-requests')) {
      return isEnglish
          ? 'Too many failed attempts. Please try again later.'
          : '試行回数が多すぎます。しばらくしてから再試行してください。';
    } else if (error.contains('network-request-failed')) {
      return isEnglish
          ? 'Network error. Please check your internet connection.'
          : 'ネットワークエラーです。インターネット接続を確認してください。';
    } else if (error.contains('Firebase認証は現在利用できません')) {
      return isEnglish
          ? 'Firebase authentication is not available. Please check Firebase configuration.'
          : 'Firebase認証が利用できません。Firebase設定を確認してください。';
    } else {
      // 詳細なエラーメッセージをそのまま表示
      return error;
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<SettingsProvider>(context, listen: false).isEnglish
                ? 'Please enter your email address first.'
                : 'まずメールアドレスを入力してください。',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendPasswordResetEmail(_emailController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Password reset email sent!'
                  : 'パスワードリセットメールを送信しました！',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInAnonymously();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Signed in as guest!'
                  : 'ゲストとしてサインインしました！',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _convertGuestToAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.convertGuestToAccount(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Account created successfully! Your guest data has been preserved.'
                  : 'アカウントが正常に作成されました！ゲストデータは保持されています。',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleWelcomeTap() async {
    if (_isSignUp || _isStartingDemo) return;

    final now = DateTime.now();
    if (_lastWelcomeTap != null &&
        now.difference(_lastWelcomeTap!).inMilliseconds > 1000) {
      _welcomeTapCount = 0;
    }

    _welcomeTapCount += 1;
    _lastWelcomeTap = now;

    if (_welcomeTapCount >= 5) {
      _welcomeTapCount = 0;
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(isEnglish ? 'Start demo mode?' : 'デモモードを開始しますか？'),
          content: Text(isEnglish
              ? 'Offline demo data will be created for all cars (TRF421, TRF420X, BD12). Continue?'
              : '全車種（TRF421 / TRF420X / BD12）のデモデータをオフラインで作成します。続行しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isEnglish ? 'Start' : '開始'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _startDemoMode();
      }
    }
  }

  Future<void> _startDemoMode() async {
    if (_isStartingDemo) return;

    setState(() {
      _isStartingDemo = true;
      _isLoading = true;
    });

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    try {
      await settingsProvider.setOfflineMode();

      final cars = settingsProvider.cars;
      if (cars.isEmpty) {
        throw Exception(isEnglish
            ? 'No cars available to create demo settings.'
            : 'デモ設定を作成できる車種が見つかりません。');
      }

      for (final car in cars) {
        final definition = getCarSettingDefinition(car.id);
        final demoSettings = _generateDemoSettingsForCar(car, definition);
        final settingName =
            isEnglish ? 'Demo - ${car.name}' : 'デモ - ${car.name}';
        await settingsProvider.addSetting(settingName, car, demoSettings);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Demo mode started. Demo settings saved.'
              : 'デモモードを開始し、デモ設定を保存しました。'),
        ));
        // Firebase未初期化でもホームへ遷移できるよう直接HomePageへ
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish
              ? 'Failed to start demo mode: $e'
              : 'デモモードの開始に失敗しました: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStartingDemo = false;
        });
      }
    }
  }

  Map<String, dynamic> _generateDemoSettingsForCar(
      Car car, CarSettingDefinition? definition) {
    final Map<String, dynamic> demo = {};

    if (definition != null) {
      for (final setting in definition.availableSettings) {
        demo[setting.key] = _getDemoValueForSetting(setting);
      }
    }

    // 基本項目を実用値で上書き（欠けている場合のみ）
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    demo.putIfAbsent('date', () => date);
    demo.putIfAbsent('airTemp', () => 25);
    demo.putIfAbsent('humidity', () => 50);
    demo.putIfAbsent('trackTemp', () => 30);
    demo.putIfAbsent('surface', () => 'カーペット');
    demo.putIfAbsent('condition', () => 'ドライ');
    demo.putIfAbsent('memo', () => 'デモデータです');

    return demo;
  }

  dynamic _getDemoValueForSetting(SettingItem setting) {
    switch (setting.type) {
      case 'number':
      case 'slider':
        return _getNumericDefault(setting);
      case 'select':
        return setting.defaultValue ??
            (setting.options != null && setting.options!.isNotEmpty
                ? setting.options!.first
                : '');
      case 'text':
        return setting.defaultValue ?? '';
      case 'grid':
        final rows = setting.constraints['rows'] as int? ?? 3;
        final cols = setting.constraints['cols'] as int? ?? 3;
        final midRow = (rows / 2).floor() + 1;
        final midCol = (cols / 2).floor() + 1;
        return [
          {'row': midRow, 'col': midCol}
        ];
      default:
        return setting.defaultValue ?? '';
    }
  }

  dynamic _getNumericDefault(SettingItem setting) {
    if (setting.defaultValue != null) {
      final parsed = double.tryParse(setting.defaultValue!);
      if (parsed != null) return parsed;
    }

    final min = setting.constraints['min'];
    final max = setting.constraints['max'];

    if (min is num && max is num) {
      return (min + max) / 2;
    }
    if (min is num) return min.toDouble();
    if (max is num) return max.toDouble();

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp
            ? (isEnglish ? 'Sign Up' : 'サインアップ')
            : (isEnglish ? 'Sign In' : 'サインイン')),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.account_circle,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _handleWelcomeTap,
                child: Text(
                  _isSignUp
                      ? (isEnglish ? 'Create Account' : 'アカウント作成')
                      : (isEnglish ? 'Welcome Back' : 'おかえりなさい'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? (isEnglish
                        ? 'Sign up to sync your settings across devices'
                        : 'デバイス間で設定を同期するためにサインアップしてください')
                    : (isEnglish
                        ? 'Sign in to access your saved settings'
                        : '保存された設定にアクセスするためにサインインしてください'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Email' : 'メールアドレス',
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isEnglish
                        ? 'Please enter your email'
                        : 'メールアドレスを入力してください';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return isEnglish
                        ? 'Please enter a valid email'
                        : '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Password' : 'パスワード',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isEnglish
                        ? 'Please enter your password'
                        : 'パスワードを入力してください';
                  }
                  if (_isSignUp && value.length < 6) {
                    return isEnglish
                        ? 'Password must be at least 6 characters'
                        : 'パスワードは6文字以上である必要があります';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Consumer<AuthService?>(
                builder: (context, authService, child) {
                  final isGuestUser = authService?.isGuestUser ?? false;

                  if (isGuestUser && _isSignUp) {
                    // ゲストユーザーがサインアップ画面にいる場合、アップグレードボタンを表示
                    return Column(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _convertGuestToAccount,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(isEnglish ? 'Create Account' : 'アカウントを作成'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isEnglish
                              ? 'This will convert your guest account to a permanent account'
                              : 'ゲストアカウントを永続アカウントに変換します',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  } else {
                    // 通常のサインイン/サインアップボタン
                    return ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp
                              ? (isEnglish ? 'Sign Up' : 'サインアップ')
                              : (isEnglish ? 'Sign In' : 'サインイン')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              if (!_isSignUp)
                TextButton(
                  onPressed: _resetPassword,
                  child: Text(isEnglish ? 'Forgot Password?' : 'パスワードを忘れましたか？'),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isSignUp
                      ? (isEnglish
                          ? 'Already have an account? '
                          : '既にアカウントをお持ちですか？ ')
                      : (isEnglish
                          ? "Don't have an account? "
                          : 'アカウントをお持ちでないですか？ ')),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(_isSignUp
                        ? (isEnglish ? 'Sign In' : 'サインイン')
                        : (isEnglish ? 'Sign Up' : 'サインアップ')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInAsGuest,
                icon: const Icon(Icons.person_outline),
                label: Text(isEnglish ? 'Continue as Guest' : 'ゲストとして続行'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEnglish
                    ? 'Guest mode allows you to save settings locally and sync to cloud without creating an account'
                    : 'ゲストモードでは、アカウントを作成せずに設定をローカルに保存し、クラウドに同期できます',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
