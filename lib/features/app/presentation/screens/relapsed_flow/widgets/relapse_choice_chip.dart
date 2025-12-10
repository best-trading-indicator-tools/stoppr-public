import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class RelapseChoiceChip extends StatefulWidget {
  final String labelKey;
  final bool singleSelect;
  final bool initiallySelected;
  final ValueChanged<bool>? onChanged;

  const RelapseChoiceChip({
    super.key,
    required this.labelKey,
    this.singleSelect = false,
    this.initiallySelected = false,
    this.onChanged,
  });

  @override
  State<RelapseChoiceChip> createState() => _RelapseChoiceChipState();
}

class _RelapseChoiceChipState extends State<RelapseChoiceChip> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initiallySelected;
  }

  void _toggle() {
    setState(() => _selected = !_selected);
    widget.onChanged?.call(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool selected = _selected;
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          l10n.translate(widget.labelKey),
          style: TextStyle(
            fontFamily: 'ElzaRound',
            color: selected ? Colors.white : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}


