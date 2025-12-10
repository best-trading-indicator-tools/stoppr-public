import 'package:flutter/material.dart';
import 'package:stoppr/main.dart';

/// Summary: Reusable language selector dropdown used across onboarding screens.
/// Displays all supported languages with flag emojis. Positioned by parent.
class OnboardingLanguageSelector extends StatelessWidget {
  const OnboardingLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          value: currentLocale,
          dropdownColor: Colors.black87,
          iconEnabledColor: Colors.white,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Colors.white,
            size: 20,
          ),
          isDense: true,
          alignment: Alignment.center,
          selectedItemBuilder: (BuildContext context) {
            return const [
              Center(child: Text("🇺🇸 EN", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇪🇸 ES", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇩🇪 DE", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇷🇺 RU", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇨🇳 ZH", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇫🇷 FR", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇸🇰 SK", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇨🇿 CS", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇵🇱 PL", style: TextStyle(color: Colors.white, fontSize: 14))),
              Center(child: Text("🇮🇹 IT", style: TextStyle(color: Colors.white, fontSize: 14))),
            ];
          },
          onChanged: (Locale? newLocale) {
            if (newLocale != null) {
              MyApp.setLocale(context, newLocale);
            }
          },
          items: const [
            DropdownMenuItem(
              value: Locale('en'),
              child: Center(
                child: Text(
                  "🇺🇸 EN",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('es'),
              child: Center(
                child: Text(
                  "🇪🇸 ES",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('de'),
              child: Center(
                child: Text(
                  "🇩🇪 DE",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('ru'),
              child: Center(
                child: Text(
                  "🇷🇺 RU",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('zh'),
              child: Center(
                child: Text(
                  "🇨🇳 ZH",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('fr'),
              child: Center(
                child: Text(
                  "🇫🇷 FR",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('sk'),
              child: Center(
                child: Text(
                  "🇸🇰 SK",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('cs'),
              child: Center(
                child: Text(
                  "🇨🇿 CS",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('pl'),
              child: Center(
                child: Text(
                  "🇵🇱 PL",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            DropdownMenuItem(
              value: Locale('it'),
              child: Center(
                child: Text(
                  "🇮🇹 IT",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

