import 'dart:math';
import 'package:flutter/material.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/breathing_animation_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/brush_teeth_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/congratulations_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/dark_chocolate_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/drink_glasses_water.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/drink_hot_tea_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/eat_salty_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/exercise_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/feeling_now_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/another_solution_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/another_way_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/other_trick_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/sugary_treat_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/try_something_else_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/high_protein_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/fruits_fiber_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/lemon_water_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/cold_sparkling_water_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/step_burst_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/visualization_script_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/burpees_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/mint_gum_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/quick_nap_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/apple_cider_vinegar_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/cold_hot_shower_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/games_screen.dart';

enum PanicTrick {
  water,
  eatSalty,
  brushTeeth,
  drinkTea,
  darkChocolate,
  exercise,
  highProtein,
  fruitsFiber,
  lemonWater,
  coldSparklingWater,
  stepBurst,
  visualizationScript,
  burpees,
  mintGum,
  quickNap,
  appleVinegar,
  coldHotShower,
  games,
  sugaryTreat, // Always last
}

class PanicFlowManager {
  static List<PanicTrick> _randomizedTricks = [];
  static int _currentIndex = 0;

  /// Initialize a new randomized flow for panic button tricks
  static void initializeRandomFlow() {
    // Create list of first 17 tricks (excluding Sugary Treat)
    final tricksToRandomize = [
      PanicTrick.water,
      PanicTrick.eatSalty,
      PanicTrick.brushTeeth,
      PanicTrick.drinkTea,
      PanicTrick.darkChocolate,
      PanicTrick.exercise,
      PanicTrick.highProtein,
      PanicTrick.fruitsFiber,
      PanicTrick.lemonWater,
      PanicTrick.coldSparklingWater,
      PanicTrick.stepBurst,
      PanicTrick.visualizationScript,
      PanicTrick.burpees,
      PanicTrick.mintGum,
      PanicTrick.quickNap,
      PanicTrick.appleVinegar,
      PanicTrick.coldHotShower,
      PanicTrick.games,
    ];

    // Shuffle the list randomly
    tricksToRandomize.shuffle(Random());

    // Add Sugary Treat as the 18th/final trick
    _randomizedTricks = [...tricksToRandomize, PanicTrick.sugaryTreat];

    // Reset current index to 0
    _currentIndex = 0;
  }

  /// Get the trick screen at the specified index
  static Widget getTrickScreen(int index) {
    if (index >= _randomizedTricks.length) {
      return const CongratulationsScreen();
    }

    final trick = _randomizedTricks[index];
    return _createTrickScreen(trick);
  }

  /// Get the next screen in the flow (could be a trick, checkpoint, or connector)
  static Widget getNextScreen() {
    _currentIndex++;

    // Check if we've exhausted all tricks
    if (_currentIndex >= _randomizedTricks.length) {
      return const CongratulationsScreen();
    }

    // Based on the current position, return the appropriate screen
    // Pattern: Trick → FeelingNow → [Connector] → Next Trick
    
    // After trick 1, we show FeelingNow → SomethingElse
    if (_currentIndex == 1) {
      return PanicFeelingNowScreen(
        nextScreen: const PanicSomethingElseScreen(),
      );
    }
    
    // After trick 2, show FeelingNow → next trick (handled below)
    
    // After trick 3, we show FeelingNow → AnotherSolution
    if (_currentIndex == 3) {
      return PanicFeelingNowScreen(
        nextScreen: const PanicAnotherSolutionScreen(),
      );
    }
    
    // After trick 4, we show FeelingNow → OtherTrick
    if (_currentIndex == 4) {
      assert(_randomizedTricks.length > _currentIndex,
          'Randomized tricks shorter than expected at index $_currentIndex');
      final trick = _randomizedTricks[_currentIndex];
      return PanicFeelingNowScreen(
        nextScreen: PanicOtherTrickScreen(
          nextScreen: _createTrickScreen(trick),
          nextScreenName: _getTrickScreenName(trick),
        ),
      );
    }
    
    // After trick 5, we show FeelingNow → AnotherWay
    if (_currentIndex == 5) {
      return PanicFeelingNowScreen(
        nextScreen: const PanicAnotherWayScreen(),
      );
    }
    
    // After trick 2, show FeelingNow → next trick (no connector)
    if (_currentIndex == 2) {
      return PanicFeelingNowScreen(
        nextScreen: getTrickScreen(_currentIndex),
      );
    }
    
    // After tricks 6-14, cycle through connector screens
    if (_currentIndex >= 6 && _currentIndex <= 14) {
      Widget connectorScreen;
      
      // Cycle through the 4 available connector screens
      final connectorIndex = (_currentIndex - 6) % 4;
      
      switch (connectorIndex) {
        case 0:
          connectorScreen = const PanicSomethingElseScreen();
          break;
        case 1:
          connectorScreen = const PanicAnotherSolutionScreen();
          break;
        case 2:
          connectorScreen = PanicOtherTrickScreen(
            nextScreen: getTrickScreen(_currentIndex),
            nextScreenName: _getTrickScreenName(_randomizedTricks[_currentIndex]),
          );
          break;
        case 3:
          connectorScreen = const PanicAnotherWayScreen();
          break;
        default:
          connectorScreen = const PanicSomethingElseScreen();
      }
      
      return PanicFeelingNowScreen(
        nextScreen: connectorScreen,
      );
    }

    // Default case (shouldn't reach here)
    return const CongratulationsScreen();
  }

  /// Get the next trick screen for connector screens
  static Widget getNextTrickForConnector() {
    // For any connector position (1..14), go to the corresponding next trick
    if (_currentIndex >= 1 && _currentIndex <= 14) {
      return getTrickScreen(_currentIndex);
    }

    // Default to congratulations if outside expected range
    return const CongratulationsScreen();
  }

  /// Create a trick screen widget based on the enum
  static Widget _createTrickScreen(PanicTrick trick) {
    switch (trick) {
      case PanicTrick.water:
        return const PanicTrickWaterScreen();
      case PanicTrick.eatSalty:
        return const PanicEatSaltyScreen();
      case PanicTrick.brushTeeth:
        return const PanicBrushTeethScreen();
      case PanicTrick.drinkTea:
        return const PanicDrinkHotTeaScreen();
      case PanicTrick.darkChocolate:
        return const PanicDarkChocolateScreen();
      case PanicTrick.exercise:
        return const PanicExerciseScreen();
      case PanicTrick.highProtein:
        return const PanicHighProteinScreen();
      case PanicTrick.fruitsFiber:
        return const PanicFruitsFiberScreen();
      case PanicTrick.lemonWater:
        return const PanicLemonWaterScreen();
      case PanicTrick.coldSparklingWater:
        return const PanicColdSparklingWaterScreen();
      case PanicTrick.stepBurst:
        return const PanicStepBurstScreen();
      case PanicTrick.visualizationScript:
        return const PanicVisualizationScriptScreen();
      case PanicTrick.burpees:
        return const PanicBurpeesScreen();
      case PanicTrick.mintGum:
        return const PanicMintGumScreen();
      case PanicTrick.quickNap:
        return const PanicQuickNapScreen();
      case PanicTrick.appleVinegar:
        return const PanicAppleVinegarScreen();
      case PanicTrick.coldHotShower:
        return const PanicColdHotShowerScreen();
      case PanicTrick.games:
        return const PanicGamesScreen();
      case PanicTrick.sugaryTreat:
        return const PanicSugaryTreatScreen();
    }
  }

  /// Get the screen name for a trick based on the enum
  static String _getTrickScreenName(PanicTrick trick) {
    switch (trick) {
      case PanicTrick.water:
        return PanicTrickWaterScreen.screenName;
      case PanicTrick.eatSalty:
        return PanicEatSaltyScreen.screenName;
      case PanicTrick.brushTeeth:
        return PanicBrushTeethScreen.screenName;
      case PanicTrick.drinkTea:
        return PanicDrinkHotTeaScreen.screenName;
      case PanicTrick.darkChocolate:
        return PanicDarkChocolateScreen.screenName;
      case PanicTrick.exercise:
        return PanicExerciseScreen.screenName;
      case PanicTrick.highProtein:
        return PanicHighProteinScreen.screenName;
      case PanicTrick.fruitsFiber:
        return PanicFruitsFiberScreen.screenName;
      case PanicTrick.lemonWater:
        return PanicLemonWaterScreen.screenName;
      case PanicTrick.coldSparklingWater:
        return PanicColdSparklingWaterScreen.screenName;
      case PanicTrick.stepBurst:
        return PanicStepBurstScreen.screenName;
      case PanicTrick.visualizationScript:
        return PanicVisualizationScriptScreen.screenName;
      case PanicTrick.burpees:
        return PanicBurpeesScreen.screenName;
      case PanicTrick.mintGum:
        return PanicMintGumScreen.screenName;
      case PanicTrick.quickNap:
        return PanicQuickNapScreen.screenName;
      case PanicTrick.appleVinegar:
        return PanicAppleVinegarScreen.screenName;
      case PanicTrick.coldHotShower:
        return PanicColdHotShowerScreen.screenName;
      case PanicTrick.games:
        return PanicGamesScreen.screenName;
      case PanicTrick.sugaryTreat:
        return PanicSugaryTreatScreen.screenName;
    }
  }

  /// Reset the flow (useful for testing)
  static void resetFlow() {
    _randomizedTricks.clear();
    _currentIndex = 0;
  }
}
