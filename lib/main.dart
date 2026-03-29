import 'package:flutter/material.dart';
import 'providers/data_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_event_screen.dart';
import 'screens/record_screen.dart';
import 'screens/analytics_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EveryTickApp());
}

class EveryTickApp extends StatefulWidget {
  const EveryTickApp({super.key});
  @override
  State<EveryTickApp> createState() => _EveryTickAppState();
}

class _EveryTickAppState extends State<EveryTickApp> {
  final _provider = DataProvider();

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DataScope(
      provider: _provider,
      child: MaterialApp(
        title: '万物打卡',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bg,
          fontFamily: 'NotoSansSC',
          useMaterial3: true,
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/event/new':
              return MaterialPageRoute(builder: (_) => const NewEventScreen());
            case '/record':
              final eventId = settings.arguments as String;
              return MaterialPageRoute(builder: (_) => RecordScreen(eventId: eventId));
            case '/analytics':
              final eventId = settings.arguments as String;
              return MaterialPageRoute(builder: (_) => AnalyticsScreen(eventId: eventId));
            default:
              return MaterialPageRoute(builder: (_) => const HomeScreen());
          }
        },
      ),
    );
  }
}
