import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'screens/role_selection_screen.dart';
import 'screens/login_screen.dart';
import 'utils/colors.dart';
import 'screens/competition_management_screen.dart';
import 'screens/athlete_home_screen.dart';
import 'screens/athlete_competition_view.dart';
import 'screens/athlete_edit_profile_screen.dart';
import 'data/competition_data.dart';
import 'data/database_helper.dart';
import 'firebase_options.dart';
import 'screens/sqlite_test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日誌系統
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final log = Logger('Main');

  // 初始化Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    log.info('✅ Firebase初始化成功');
  } catch (e) {
    log.severe('❌ Firebase初始化失敗: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 初始化SQLite數據庫
  try {
    // 使用DatabaseHelper初始化
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // 確保數據庫初始化
    final path = await dbHelper.getDatabasePath();
    final count = await dbHelper.getCompetitionCount();
    log.info('數據庫初始化成功! 路徑: $path, 比賽數量: $count');

    // 使用 CompetitionData 預加載數據 - 這會間接使用 DatabaseHelper
    final compData = CompetitionData();
    await compData.loadCompetitions();
    log.info('比賽數據預加載完成');

    // 檢查數據庫狀態
    final status = await compData.checkSQLiteStatus();
    if (status['success'] == true) {
      log.info('SQLite狀態: 正常，路徑: ${status['path']}, 數量: ${status['count']}');
    } else {
      log.warning('SQLite狀態: 異常，錯誤: ${status['error']}');
    }
  } catch (e) {
    log.severe('數據庫初始化錯誤: $e');
  }

  runApp(const SportsEventApp());
}

class SportsEventApp extends StatelessWidget {
  const SportsEventApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '運動賽事管理系統',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: mobileBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: mobileBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
        ),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/athlete-edit-profile': (context) => const AthleteEditProfileScreen(),
        '/competition-management': (context) =>
            const CompetitionManagementScreen(),
        '/athlete-home': (context) => AthleteHomeScreen(
              userId:
                  ModalRoute.of(context)?.settings.arguments as String? ?? '',
            ),
        '/competition-view': (context) => const AthleteCompetitionViewScreen(),
        '/sqlite_test': (context) => const SQLiteTestScreen(),
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Athletics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '運動賽事管理系統',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '專業的賽事管理平台，為您提供最佳的運動體驗',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/role-selection');
                },
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    color: Colors.white,
                  ),
                  child: const Text(
                    '開始使用',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
