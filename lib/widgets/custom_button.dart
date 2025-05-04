import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Icon? icon;
  final double? iconSpacing;
  final bool fullWidth;
  final bool hasShadow;
  final Gradient? gradient;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.fontSize,
    this.padding,
    this.borderRadius = 12.0,
    this.icon,
    this.iconSpacing = 8.0,
    this.fullWidth = true,
    this.hasShadow = true,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: (backgroundColor ?? primaryColor).withOpacity(0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: fullWidth ? double.infinity : null,
          height: height,
          alignment: Alignment.center,
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
              side: isOutlined
                  ? BorderSide(
                      color: backgroundColor ?? primaryColor, width: 1.5)
                  : BorderSide.none,
            ),
            color: isOutlined
                ? Colors.transparent
                : (gradient != null ? null : (backgroundColor ?? primaryColor)),
            gradient: isOutlined ? null : gradient,
            shadows: (isOutlined || !hasShadow)
                ? []
                : [
                    BoxShadow(
                      color: (backgroundColor ?? primaryColor).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: isOutlined
                        ? (backgroundColor ?? primaryColor)
                        : (textColor ?? Colors.white),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      IconTheme(
                        data: IconThemeData(
                          color: isOutlined
                              ? (backgroundColor ?? primaryColor)
                              : (textColor ?? Colors.white),
                          size: (fontSize ?? 16) + 4,
                        ),
                        child: icon!,
                      ),
                      SizedBox(width: iconSpacing),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize ?? 16,
                        color: isOutlined
                            ? (backgroundColor ?? primaryColor)
                            : (textColor ?? Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
