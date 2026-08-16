import 'package:flutter/material.dart';
import 'package:datacare/src/rust/api/simple.dart';

class DataCareApp extends StatelessWidget {
  const DataCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataCare',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const Scaffold(
        body: Center(
          child: HelloWorldWidget(),
        ),
      ),
    );
  }
}

class HelloWorldWidget extends StatefulWidget {
  const HelloWorldWidget({super.key});

  @override
  State<HelloWorldWidget> createState() => _HelloWorldWidgetState();
}

class _HelloWorldWidgetState extends State<HelloWorldWidget> {
  String _greeting = 'Waiting for Rust...';

  @override
  void initState() {
    super.initState();
    _loadGreeting();
  }

  void _loadGreeting() {
    try {
      final greeting = greet(name: 'DataCare User');
      setState(() {
        _greeting = greeting;
      });
    } catch (e) {
      setState(() {
        _greeting = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _greeting,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadGreeting,
          child: const Text('Refresh Greeting'),
        ),
      ],
    );
  }
}
