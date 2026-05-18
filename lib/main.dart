import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'repositories/lecturer_catalog_repository.dart';
import 'repositories/security_repository.dart';
import 'repositories/student_repository.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme_controller.dart';
import 'features/translation/translation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await TranslationController.instance.loadSavedPreference();
  await Hive.openBox<dynamic>(StudentRepository.coursesBoxName);
  await Hive.openBox<dynamic>(LecturerCatalogRepository.boxName);
  await Hive.openBox<dynamic>(SecurityRepository.metadataBoxName);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App uses a non-Firebase login (studentId/email), but Firestore/Storage rules
  // require an authenticated Firebase session for writes. Anonymous auth keeps
  // client requests "signed-in" without changing the app's login UX.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
    // If auth isn't enabled in Firebase Console, rules will still deny writes.
  }
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing — copy .env.example to .env and add OPENAI_KEY
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _brandTeal = Color(0xFF27A2A9);
  static const _brandTealDark = Color(0xFF006571);
  static const _textOnLight = Color(0xFF111827);

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    colorScheme: const ColorScheme.light(
      primary: _brandTealDark,
      onPrimary: Colors.white,
      secondary: _brandTeal,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: _textOnLight,
      error: Color(0xFFB71C1C),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    colorScheme: const ColorScheme.dark(
      primary: _brandTeal,
      onPrimary: Colors.black,
      secondary: _brandTeal,
      onSecondary: Colors.black,
      surface: Color(0xFF0B1220),
      onSurface: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFF050A14),
    cardTheme: const CardThemeData(
      color: Color(0xFF0B1220),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        final translation = TranslationController.instance;
        return AnimatedBuilder(
          animation: translation,
          builder: (context, _) {
            return MaterialApp(
              title: 'Flutter Demo',
              theme: _lightTheme,
              darkTheme: _darkTheme,
              themeMode: mode,
              locale: translation.locale,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ar'), Locale('en')],
              builder: (context, child) => Directionality(
                textDirection: translation.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
