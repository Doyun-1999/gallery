import 'package:flutter/material.dart';
import 'package:gallery_memo/screen/home_screen.dart';
import 'package:gallery_memo/screen/login_screen.dart';
import 'screen/signup_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case '/':       return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/signup': return MaterialPageRoute(builder: (_) => const SignUpPage());
      case '/home':   return MaterialPageRoute(builder: (_) => const HomeScreen());
      default:        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}