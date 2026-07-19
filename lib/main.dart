import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/ids_state.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_shell.dart';

void main() {
  runApp(const NetworkIdsApp());
}

class NetworkIdsApp extends StatelessWidget {
  const NetworkIdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IdsState(),
      child: MaterialApp(
        title: 'ScreenX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Checks for a stored token on launch and routes straight to the dashboard
/// if the user is already logged in, otherwise shows the login screen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final state = context.read<IdsState>();
    return FutureBuilder<bool>(
      future: state.api.isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          state.startListening();
          return const DashboardShell();
        }
        return const LoginScreen();
      },
    );
  }
}
