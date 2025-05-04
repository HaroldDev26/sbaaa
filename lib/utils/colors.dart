import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF0F0F54);
const Color secondaryColor = Colors.white;
const Color mobileBackgroundColor = Color(0xFFE2E8F0);
const Color webBackgroundColor = Color(0xFFE2E8F0);
const Color darkBlueColor = Color(0xFF0F0F54);
const Color textFieldBackground = Colors.white;
const Color textFieldBorder = Color(0xFFEAEAEA);

// 添加顏色擴展方法
extension ColorExtension on Color {
  /// 設置顏色的 alpha 值或其它顏色組件
  /// alpha 參數範圍應在 0.0 到 1.0 之間
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromRGBO(
      red ?? this.r.toInt(),
      green ?? this.g.toInt(),
      blue ?? this.b.toInt(),
      alpha ?? this.opacity,
    );
  }
}
