import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app/local_reminders.dart';
import 'app/seed.dart';
import 'app/store.dart';
import 'app/theme.dart';
import 'core/finance/finance_core.dart';
import 'ui/onboarding_screen.dart';
import 'ui/savings_move_screen.dart';
import 'ui/shell.dart';
import 'ui/splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Giấy phép của phông Be Vietnam Pro, hiện trong mục giấy phép của app.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Be Vietnam Pro'], text);
  });
  runApp(const TichiBoot());
}

/// Hiện màn hình chuyển trong lúc mở cơ sở dữ liệu, rồi vào app.
class TichiBoot extends StatefulWidget {
  const TichiBoot({super.key});

  @override
  State<TichiBoot> createState() => _TichiBootState();
}

class _TichiBootState extends State<TichiBoot> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _reminders = LocalReminders();
  AppStore? _store;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final directory = await getApplicationSupportDirectory();
    final core = FinanceCore(sqlite3.open('${directory.path}/tichi.db'))
      ..migrate();
    seedIfEmpty(core);
    final store = AppStore(core, reminders: _reminders);
    var fromReminder = false;
    try {
      await _reminders.init(onTap: _openSaving);
      fromReminder = await _reminders.launchedFromReminder();
    } catch (_) {
      // Không có thông báo thì app vẫn chạy bình thường.
    }
    final wait =
        const Duration(milliseconds: 1400) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    setState(() => _store = store);
    unawaited(store.syncReminder());
    if (fromReminder) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSaving());
    }
  }

  /// Bấm vào thông báo nhắc: mở thẳng màn hình Tiết kiệm ngay.
  void _openSaving() {
    final store = _store;
    if (store == null || !store.onboardingDone) return;
    _navigatorKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) =>
            const SavingsMoveScreen(mode: SavingsMode.contribute)));
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: store == null
            ? MaterialApp(
                key: const ValueKey('splash'),
                debugShowCheckedModeBanner: false,
                theme: buildTheme(),
                home: const SplashView(),
              )
            : TichiApp(
                key: const ValueKey('app'),
                store: store,
                navigatorKey: _navigatorKey,
              ),
      ),
    );
  }
}

class TichiApp extends StatefulWidget {
  const TichiApp({super.key, required this.store, this.navigatorKey});

  final AppStore store;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<TichiApp> createState() => _TichiAppState();
}

/// Theo dõi lựa chọn Sáng/Tối/Theo máy và chế độ tối của điện thoại, rồi vẽ
/// lại toàn bộ màn hình khi giao diện đổi.
class _TichiAppState extends State<TichiApp> with WidgetsBindingObserver {
  late Brightness _brightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_update);
    _brightness = _resolve();
    TichiColors.dark = _brightness == Brightness.dark;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_update);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _update();

  Brightness _resolve() => switch (widget.store.themeMode) {
        'light' => Brightness.light,
        'dark' => Brightness.dark,
        _ => WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  void _update() {
    final next = _resolve();
    if (next == _brightness || !mounted) return;
    setState(() {
      _brightness = next;
      TichiColors.dark = next == Brightness.dark;
    });
    // Màu của các màn hình đọc từ TichiColors, không qua Theme, nên phải bảo
    // từng phần vẽ lại một lượt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = _brightness == Brightness.dark;
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: TichiColors.surface,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: StoreScope(
        store: widget.store,
        child: MaterialApp(
          title: 'Tichi',
          navigatorKey: widget.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _StartGate(),
        ),
      ),
    );
  }
}

/// Lần đầu mở app thì hiện hướng dẫn, sau đó vào thẳng Trang chủ.
class _StartGate extends StatelessWidget {
  const _StartGate();

  @override
  Widget build(BuildContext context) {
    final done = StoreScope.of(context).onboardingDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: done
          ? const HomeShell(key: ValueKey('home'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}
