
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Using 'Indigo' for a premium, trustworthy academic look.
  static final light = FlexThemeData.light(
    scheme: FlexScheme.indigo,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useTextTheme: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      inputDecoratorRadius: 12.0,
      cardRadius: 12.0,
      popupMenuRadius: 8.0,
      dialogRadius: 16.0,
      fabRadius: 16.0,
    ),
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily ?? GoogleFonts.inter().fontFamily,
    
    // Force pure white background for "White Mode"
    scaffoldBackground: Colors.white,
  );

  static final dark = FlexThemeData.dark(
    scheme: FlexScheme.indigo,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useTextTheme: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      inputDecoratorRadius: 12.0,
      cardRadius: 12.0,
      popupMenuRadius: 8.0,
      dialogRadius: 16.0,
      fabRadius: 16.0,
    ),
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.outfit().fontFamily ?? GoogleFonts.inter().fontFamily,
    // Dark mode background is handled well by FlexThemeData defaults (usually dark grey/black)
  );
}
