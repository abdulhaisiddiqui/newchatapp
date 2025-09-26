import 'package:chatapp/components/my_button.dart';
import 'package:chatapp/components/my_new_field.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  const LoginPage({super.key, this.onTap});

  @override
  State<LoginPage> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Sign in user
  void signIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signInWithEmailOrPassword(
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
      appBar: AppBar(
        leading: Icon(Icons.arrow_back),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo or Header Image
                Image.asset(
                  'assets/images/Login_text.png',
                  width: 210,
                  height: 35,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),

                // Description Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Text(
                    'Welcome back! Sign in using your social account or email to continue us',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff797C7B),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                //social media icons
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: BoxBorder.fromBorderSide(BorderSide(color: Colors.black)),
                    borderRadius: BorderRadius.circular(9)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.facebook,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                      SizedBox(width: 16),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage(
                          'assets/images/google-logo.png',
                        ), // Ensure you have a Google logo image in your assets
                      ),
                      SizedBox(width: 16),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage(
                          'assets/images/Apple_Inc.-Logo.wine (1).png',
                        ), // Ensure you have an Apple logo image in your assets
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                    children: <Widget>[
                      Expanded(
                          child: Divider()
                      ),

                      Text("   OR   ",style: TextStyle(color: Colors.grey),),

                      Expanded(
                          child: Divider()
                      ),
                    ]
                ),

                const SizedBox(height: 24),

                // Email TextField
                MyNewField(
                  controller: emailController,
                  hintText: 'Email',
                  text: 'Your email',
                  obscureText: false,
                ),

                const SizedBox(height: 12),

                // Password TextField
                MyNewField(
                  controller: passwordController,
                  hintText: 'Password',
                  text: 'Your Password',
                  obscureText: true,
                ),

                const SizedBox(height: 24),
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Not a member?"),
                    SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        'Register now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: MyButton(ontap: signIn, text: 'Log in'),
                ),

                const SizedBox(height: 12),

                // Forgot password
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
                ),

                const SizedBox(height: 16),


              ],
            ),
          ),
        ),
      ),
    );
  }
}
