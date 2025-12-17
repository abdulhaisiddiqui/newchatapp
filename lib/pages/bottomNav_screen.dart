import 'package:chatapp/pages/call_screen.dart';
import 'package:chatapp/pages/contact_screen.dart';
import 'package:chatapp/pages/home_page.dart';
import 'package:chatapp/pages/setting_screen.dart';
import 'package:chatapp/pages/setting_screen2.dart';
import 'package:flutter/material.dart';

import '../components/uihelper.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int currentIndex = 0;
  List<Widget> pages = [
    HomePage(),
    CallScreen(),
    ContactScreen(),
    SettingScreen2(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: UiHelper.CustomImage(img: "Message.png"),
            label: "Mssage",
          ),
          BottomNavigationBarItem(
            icon: UiHelper.CustomImage(img: "call.png"),
            label: "Calls",
          ),
          BottomNavigationBarItem(
            icon: UiHelper.CustomImage(img: "user.png"),
            label: "Contacts",
          ),
          BottomNavigationBarItem(
            icon: UiHelper.CustomImage(img: "settings.png"),
            label: "Settings",
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
