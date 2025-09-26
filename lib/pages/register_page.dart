import 'package:chatapp/components/my_button.dart';
import 'package:chatapp/components/my_new_field.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // sign up user
  void signUp() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Password Does'nt match!")));

      return;
    }
    // get auth Service
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signUpWithEmailandPassword(
        usernameController.text,
        emailController.text,
        passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 50),
                Icon(Icons.message, size: 100, color: Colors.grey[800]),

                SizedBox(height: 50),
                // let's create Text
                Text(
                  "Let\'s create an account for you!",
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 25),
                //Username Field
                MyNewField(controller: usernameController,text: 'Username', hintText: 'Username', obscureText: false),
                //Email TextFields
                MyNewField(
                  controller: emailController,
                  hintText: 'Email',
                  text: 'Passwordjkjk',
                  obscureText: false,
                ),

                SizedBox(height: 10),
                // Password Fields
                MyNewField(
                  controller: passwordController,
                  hintText: 'Password',
                  text: 'Passwordjkjk',
                  obscureText: true,
                ),

                SizedBox(height: 10),
                MyNewField(
                  controller: confirmPasswordController,
                  hintText: 'Confirm Password',
                  text: 'Passwordjkjk',
                  obscureText: true,
                ),

                SizedBox(height: 25),

                MyButton(ontap: signUp, text: 'Sign Up'),

                SizedBox(height: 50),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already a member?'),
                    SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
