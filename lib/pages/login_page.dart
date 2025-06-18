import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/settings_provider.dart';

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
    final isEnglish = Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    
    if (error.contains('user-not-found')) {
      return isEnglish ? 'No user found for that email.' : 'そのメールアドレスのユーザーが見つかりません。';
    } else if (error.contains('wrong-password')) {
      return isEnglish ? 'Wrong password provided.' : 'パスワードが間違っています。';
    } else if (error.contains('email-already-in-use')) {
      return isEnglish ? 'The account already exists for that email.' : 'そのメールアドレスのアカウントは既に存在します。';
    } else if (error.contains('weak-password')) {
      return isEnglish ? 'The password provided is too weak.' : 'パスワードが弱すぎます。';
    } else if (error.contains('invalid-email')) {
      return isEnglish ? 'The email address is not valid.' : 'メールアドレスが無効です。';
    } else {
      return isEnglish ? 'An error occurred. Please try again.' : 'エラーが発生しました。もう一度お試しください。';
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: Text(
              isEnglish ? 'Skip' : 'スキップ',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
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
              Text(
                _isSignUp 
                    ? (isEnglish ? 'Create Account' : 'アカウント作成')
                    : (isEnglish ? 'Welcome Back' : 'おかえりなさい'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp 
                    ? (isEnglish ? 'Sign up to sync your settings across devices' : 'デバイス間で設定を同期するためにサインアップしてください')
                    : (isEnglish ? 'Sign in to access your saved settings' : '保存された設定にアクセスするためにサインインしてください'),
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
                    return isEnglish ? 'Please enter your email' : 'メールアドレスを入力してください';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return isEnglish ? 'Please enter a valid email' : '有効なメールアドレスを入力してください';
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
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isEnglish ? 'Please enter your password' : 'パスワードを入力してください';
                  }
                  if (_isSignUp && value.length < 6) {
                    return isEnglish ? 'Password must be at least 6 characters' : 'パスワードは6文字以上である必要があります';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
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
                      ? (isEnglish ? 'Already have an account? ' : '既にアカウントをお持ちですか？ ')
                      : (isEnglish ? "Don't have an account? " : 'アカウントをお持ちでないですか？ ')),
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
            ],
          ),
        ),
      ),
    );
  }
}