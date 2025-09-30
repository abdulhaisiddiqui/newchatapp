// This file provides stub implementations for dart:io classes for web platform
import 'package:flutter/foundation.dart';

// File stub for web
class File {
  final String path;
  
  File(this.path);
  
  Future<bool> exists() async => false;
  Future<File> create({bool recursive = false}) async => this;
  Future<File> copy(String newPath) async => File(newPath);
  Future<DateTime> lastModified() async => DateTime.now();
  Future<int> length() async => 0;
  Future<File> delete({bool recursive = false}) async => this;
}

// Directory stub for web
class Directory {
  final String path;
  
  Directory(this.path);
  
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

// FileSystemEntity stub
class FileSystemEntity {
  static Future<bool> isDirectory(String path) async => false;
  static Future<bool> isFile(String path) async => false;
}