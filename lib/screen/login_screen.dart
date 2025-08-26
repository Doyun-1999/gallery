import 'package:flutter/material.dart';
import 'package:gallery_memo/screen/signup_screen.dart';
import 'home_screen.dart';

// Firebase Auth, Google, Apple 관련 import (추후 사용)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() => runApp(const AuthApp());

class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '인증 스켈레톤',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
      routes: {
        '/': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // TODO: Firebase Auth signInWithEmailAndPassword 로 교체
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/home');
  }

  // 구글 로그인
  // Future<void> _onGoogleLogin() async {
  //   try {
  //     // 1. 인스턴스 생성
  //     final GoogleSignIn googleSignIn = GoogleSignIn(
  //       scopes: ['email'],
  //     );
  //
  //     // 2. 구글 로그인 시작
  //     final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  //     if (googleUser == null) return; // 사용자가 취소함
  //
  //     // 3. 인증 정보 가져오기
  //     final GoogleSignInAuthentication googleAuth =
  //     await googleUser.authentication;
  //
  //     // 4. Firebase 자격 증명으로 교환
  //     final OAuthCredential credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );
  //
  //     // 5. Firebase 로그인
  //     await FirebaseAuth.instance.signInWithCredential(credential);
  //
  //     if (!mounted) return;
  //     Navigator.pushReplacementNamed(context, '/home');
  //   } catch (e) {
  //     debugPrint("구글 로그인 오류: $e");
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('구글 로그인 실패')),
  //       );
  //     }
  //   }
  // }

  // 애플 로그인
  Future<void> _onAppleLogin() async {
    try {
      // TODO: Firebase + Apple Sign-In 연동
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('애플 로그인 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('애플 로그인 실패')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(labelText: '이메일'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '이메일을 입력해 주세요';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                        if (!ok) return '올바른 이메일 형식이 아닙니다';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          tooltip: _obscure ? '비밀번호 보기' : '비밀번호 가리기',
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 입력해 주세요';
                        if (v.length < 8) return '비밀번호는 8자 이상이어야 해요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _loading ? null : _onLogin,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('이메일로 로그인'),
                    ),

                    const SizedBox(height: 12),

                    // 🔹 Google 로그인 버튼
                    OutlinedButton.icon(
                      onPressed: null,
                      //_onGoogleLogin,
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Google 계정으로 로그인'),
                    ),

                    const SizedBox(height: 8),

                    // 🔹 Apple 로그인 버튼 (iOS 전용)
                    OutlinedButton.icon(
                      onPressed: _onAppleLogin,
                      icon: const Icon(Icons.apple),
                      label: const Text('Apple 계정으로 로그인'),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('아직 계정이 없나요? '),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                          child: const Text('회원가입'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}