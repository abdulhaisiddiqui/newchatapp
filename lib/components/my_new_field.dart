import 'package:flutter/material.dart';

class MyNewField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String? text;


  const MyNewField({super.key,this.text, required this.controller,required this.hintText,required this.obscureText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: text,
        labelStyle: TextStyle(color: Color(0XFF24786D),fontSize: 14,fontWeight: FontWeight.w500),
        border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.email, color: Colors.teal),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0XFFCDD1D0), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0XFFCDD1D0), width: 2),
        ),


      ),
    );
  }
}
