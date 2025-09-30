import 'package:chatapp/components/my_button.dart';
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
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Validate email format
  bool isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email);
  }

  // Sign in user
  void signIn() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    
    // Set loading state
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signInWithEmailOrPassword(
        emailController.text.trim(),
        passwordController.text,
      );
    } catch (e) {
      // Show specific error message based on exception
      String errorMessage = 'An error occurred. Please try again.';
      
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'No user found with this email.';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email format.';
      } else if (e.toString().contains('user-disabled')) {
        errorMessage = 'This account has been disabled.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many attempts. Try again later.';
      }
      
      // Check if widget is still mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      // Reset loading state only if still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: Image.asset(
                            'assets/images/google-logo.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Image.asset(
                            'assets/images/Apple_on.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Image.asset(
                            'assets/images/Facebook-f_Logo-Blue-Logo.wine.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  const SizedBox(height: 24),
  
                  Row(
                    children: const <Widget>[
                      Expanded(
                        child: Divider()
                      ),
  
                      Text("   OR   ", style: TextStyle(color: Colors.grey)),
  
                      Expanded(
                        child: Divider()
                      ),
                    ]
                  ),
  
                  const SizedBox(height: 24),
  
                  // Email TextField with validation
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Your email',
                      hintText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email, color: Color(0XFF24786D)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0XFFCDD1D0), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0XFF24786D), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!isValidEmail(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
  
                  const SizedBox(height: 12),
  
                  // Password TextField with validation
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Your Password',
                      hintText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: Color(0XFF24786D)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0XFFCDD1D0), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0XFF24786D), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
  
                  const SizedBox(height: 24),
                  
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Not a member?"),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: const Text(
                          'Register now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0XFF24786D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
  
                  // Login Button with loading indicator
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0XFF24786D)))
                      : MyButton(ontap: signIn, text: 'Log in'),
                  ),

                  const SizedBox(height: 12),

                  // Forgot password
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Color(0XFF24786D)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
