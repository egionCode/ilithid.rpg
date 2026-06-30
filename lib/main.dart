import 'package:flutter/material.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ilithid',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Welcome to ilithid RPG Helper'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  client.ping();
                },
                child: const Text('Send a ping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
