import 'package:chatapp/pages/bottomNav_screen.dart';
import 'package:chatapp/services/auth/login_or_register.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshots) {
          // user is logged in
          if (snapshots.hasData) {
            return const BottomNavScreen();
          } else {
            return const LoginOrRegister();
          }

          // user is not logged in
        },
      ),
    );
  }
}
