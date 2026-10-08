import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class CRDashboard extends StatelessWidget {
  const CRDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CR'),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: const Center(
        child: Text('CR Dashboard', style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}
