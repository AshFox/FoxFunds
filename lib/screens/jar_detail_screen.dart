import 'package:flutter/material.dart';
import 'package:foxfunds/models/jar.dart';

class JarDetailScreen extends StatelessWidget {
  final Jar jar;

  const JarDetailScreen({super.key, required this.jar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(jar.name),
      ),
      body: Center(
        child: Text('Details for ${jar.name}'),
      ),
    );
  }
}
