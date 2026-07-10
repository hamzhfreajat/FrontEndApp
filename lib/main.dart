import 'firebase_options.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';

import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/saved_search_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'widgets/connectivity_wrapper.dart';
import 'services/api_service.dart';
import 'screens/ad_details_page.dart';
import 'screens/category_details_page.dart';
import 'features/chat/presentation/screens/premium_inbox_screen.dart';
import 'services/analytics_engine.dart';
import 'utils/analytics_route_observer.dart';
import 'widgets/dead_click_detector.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final AnalyticsRouteObserver analyticsRouteObserver = AnalyticsRouteObserver();

// Ignore SSL handshake warnings for development and R2 dev bucket URLs on older/restricted emulators
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Handling a background message: ${message.messageId}");

  if (message.data['type'] == 'chat_message') {
    final chatId = message.data['chat_id']?.toString();
    final messageId = message.data['message_id']?.toString();

    if (chatId != null && chatId.isNotEmpty && messageId != null && messageId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({'status': 'delivered'});
      } catch (e) {
        print("Failed to update message status to delivered: $e");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  MobileAds.instance.initialize();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AnalyticsEngine().logError(
      error: details.exceptionAsString(),
      stackTrace: details.stack?.toString() ?? '',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AnalyticsEngine().logError(
      error: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };
  
  AnalyticsEngine().initialize();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // transparent status bar
    statusBarIconBrightness: Brightness.dark, // dark icons
    statusBarBrightness: Brightness.light, // for iOS
  ));
  
  try {
    HttpOverrides.global = MyHttpOverrides();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e, stack) {
    print('CRITICAL ERROR DURING FIREBASE INIT: $e\n$stack');
  }

  // Initialize the high importance channel for Android 8+
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  // Initialize flutterLocalNotificationsPlugin properly so we can handle clicks
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'chat_message') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const PremiumInboxScreen()),
        );
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Handle clicking on push notifications when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print('Notification clicked! Data: ${message.data}');
    
    if (message.data['type'] == 'chat_message') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const PremiumInboxScreen()),
      );
      return;
    }

    if (message.data.containsKey('reference_id')) {
      if (message.data['type'] == 'saved_search_batch') {
        try {
          final filterId = message.data['reference_id'].toString();
          final savedSearches = await ApiService().fetchSavedSearches();
          final savedSearch = savedSearches.firstWhere((s) => s.id == filterId);
          
          final appProvider = Provider.of<AppProvider>(navigatorKey.currentContext!, listen: false);
          final categories = appProvider.categories ?? [];
          final category = categories.isNotEmpty 
              ? categories.firstWhere((c) => c.id == savedSearch.categoryId, orElse: () => categories.first)
              : null;
          
          if (category != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => CategoryDetailsPage(
                category: category,
                initialSearchQuery: savedSearch.searchQuery,
                initialMinPrice: savedSearch.minPrice,
                initialMaxPrice: savedSearch.maxPrice,
                initialTags: savedSearch.tags,
                initialLocations: savedSearch.locations,
                initialShowSaveSearch: false,
              )),
            );
          }
        } catch (e) {
          print('Error navigating to saved search: $e');
        }
        return;
      }
      
      try {
        final adId = int.parse(message.data['reference_id']);
        final ad = await ApiService().fetchAdById(adId);
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)),
        );
      } catch (e) {
        print('Error navigating to ad from push notification: $e');
      }
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()..refreshAll()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SavedSearchProvider()),
      ],
      child: DeadClickDetector(
        child: const OpenSooqApp(),
      ),
    ),
  );
}

class OpenSooqApp extends StatelessWidget {
  const OpenSooqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [analyticsRouteObserver],
      title: 'سوقكم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        primarySwatch: Colors.blue,
        cardColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFFF3F4F9),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B), // Dark slate premium color
          contentTextStyle: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          actionTextColor: const Color(0xFF3B82F6),
        ),
        textTheme: GoogleFonts.tajawalTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      builder: (context, child) {
        final settings = Provider.of<SettingsProvider>(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ConnectivityWrapper(child: child!),
        );
      },
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ar'),
      home: const SplashScreen(),
    );
  }
}
