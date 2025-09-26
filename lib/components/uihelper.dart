import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class UiHelper {
  static CustomImage({required String img}) {
    return Image.asset("assets/images/$img",height: 24,width: 24,color: Colors.grey,);
  }
}