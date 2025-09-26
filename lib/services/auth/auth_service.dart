import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier{
  //instance of auth
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  //instance of firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //sign user in
 Future<UserCredential> signInWithEmailOrPassword(String email, String password) async{
   try{
     UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);

     //add a new document for the user in users collection if it doesn't already exists
     _firestore.collection('users').doc(userCredential.user!.uid).set({
       'uid': userCredential.user!.uid,
       'email': email
     },SetOptions(merge: true));
     return userCredential;
   }
   on FirebaseAuthException catch(e){
     throw Exception(e.code);
   }
 }

 // create a new user
  Future<UserCredential> signUpWithEmailandPassword(String username,
      String email,password) async{
   try{
     UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);

     //after creating the user, create a new document for the user in the user collection
     _firestore.collection('users').doc(userCredential.user!.uid).set({
       'uid': userCredential.user!.uid,
       'email': email,
       'profilePic': "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQxSFDJsQuUfNJriz0KiaTD28GR82xL1fW-nvsEF9GwaI_sq6SkPloo&usqp=CAE&s",
       'username':username
     });
     
     return userCredential;
   }on FirebaseAuthException catch (e){
     throw Exception(e.code);
   }
  }

  //sign user out

Future<void> signOut() async{

   return await FirebaseAuth.instance.signOut();
}
}