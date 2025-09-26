import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final void Function()? ontap;
  final String text;

  const MyButton({super.key, required this.ontap, required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0XFF24786D),
          borderRadius: BorderRadius.circular(9)
        ),
        child: Center(
          child: Text(text,style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        ),
      ),
    );
  }
}
