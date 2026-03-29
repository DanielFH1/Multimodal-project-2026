import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/search/search_screen.dart';

class ShelfieApp extends StatelessWidget {
  const ShelfieApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark status bar + nav bar to match the dark UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF101014),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'Shelfie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
          surface: const Color(0xFF101014),
        ),
        scaffoldBackgroundColor: const Color(0xFF101014),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2D3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: const SearchScreen(),
    );
  }
}
