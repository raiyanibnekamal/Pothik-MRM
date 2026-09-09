import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_text.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.prefix,
    this.maxLength,
    this.obscureText = false,
    this.onChanged,
    this.enabled = true,
    this.inputFormatters,
    this.textInputAction,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final int? maxLength;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.helper(AppColors.textPrimary).copyWith(
          fontWeight: FontWeight.w500,
        )),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onChanged: onChanged,
            style: AppText.body(),
            cursorColor: AppColors.interactivePrimary,
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: AppText.body(AppColors.textDisabled),
              prefixIcon: prefix,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(
                  color: hasError ? AppColors.danger : AppColors.borderStrong,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(
                  color: hasError ? AppColors.danger : AppColors.interactiveAccent,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(errorText!, style: AppText.helper(AppColors.danger)),
        ] else if (helper != null) ...[
          const SizedBox(height: 8),
          Text(helper!, style: AppText.helper()),
        ],
      ],
    );
  }
}

class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.error = false,
    this.shakeToken = 0,
    this.initialValue,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool error;
  final int shakeToken;
  final String? initialValue;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes>
    with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _cs;
  late final List<FocusNode> _fs;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? '';
    _cs = List.generate(
      widget.length,
      (i) => TextEditingController(text: i < initial.length ? initial[i] : ''),
    );
    _fs = List.generate(widget.length, (_) => FocusNode());
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onChanged?.call(_value);
      if (_fs.isEmpty) return;
      final filled = initial.length.clamp(0, widget.length);
      if (filled >= widget.length) {
        _fs.last.requestFocus();
      } else {
        _fs[filled].requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeToken != oldWidget.shakeToken) {
      _shake.forward(from: 0);
      for (final c in _cs) {
        c.clear();
      }
      _fs.first.requestFocus();
    }
  }

  @override
  void dispose() {
    for (final c in _cs) {
      c.dispose();
    }
    for (final f in _fs) {
      f.dispose();
    }
    _shake.dispose();
    super.dispose();
  }

  String get _value => _cs.map((c) => c.text).join();

  void _onChanged(int i, String v) {
    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < widget.length; k++) {
        _cs[k].text = k < digits.length ? digits[k] : '';
      }
      final last = digits.length.clamp(0, widget.length - 1);
      _fs[last].requestFocus();
    } else if (v.isNotEmpty && i < widget.length - 1) {
      _fs[i + 1].requestFocus();
    } else if (v.isEmpty && i > 0) {
      _fs[i - 1].requestFocus();
    }
    final value = _value;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anim = Tween(begin: 0.0, end: 8.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shake);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Transform.translate(
        offset: Offset(anim.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (i) {
          return SizedBox(
            width: 48,
            height: 60,
            child: TextField(
              controller: _cs[i],
              focusNode: _fs[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: AppText.otp(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => _onChanged(i, v),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.navy50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(
                    color: widget.error ? AppColors.danger : AppColors.borderStrong,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(
                    color: widget.error
                        ? AppColors.danger
                        : AppColors.interactiveAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
