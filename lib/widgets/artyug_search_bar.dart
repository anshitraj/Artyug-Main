import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ArtyugSearchRouteTrigger extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;
  final double height;

  const ArtyugSearchRouteTrigger({
    super.key,
    this.hintText = 'Search artists, creators, artworks…',
    required this.onTap,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowOf(context, alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: AppColors.textMutedOf(context),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMutedOf(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtyugSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool autofocus;

  const ArtyugSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search artists, creators, artworks…',
    this.readOnly = false,
    this.onTap,
    this.trailing,
    this.autofocus = false,
  });

  @override
  State<ArtyugSearchBar> createState() => _ArtyugSearchBarState();
}

class _ArtyugSearchBarState extends State<ArtyugSearchBar> {
  late final FocusNode _internalFocus;
  FocusNode get _effectiveFocus => widget.focusNode ?? _internalFocus;
  bool _ownsFocus = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _internalFocus = FocusNode();
    _effectiveFocus.addListener(_onFocus);
    _focused = _effectiveFocus.hasFocus;
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = _effectiveFocus.hasFocus);
  }

  @override
  void dispose() {
    _effectiveFocus.removeListener(_onFocus);
    if (_ownsFocus) _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused
        ? AppColors.accentOf(context).withValues(alpha: 0.75)
        : AppColors.borderOf(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: _focused ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? AppColors.accentOf(context).withValues(alpha: 0.16)
                : AppColors.shadowOf(context, alpha: 0.45),
            blurRadius: _focused ? 16 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.readOnly ? widget.onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.textMutedOf(context),
                    size: 21,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode ?? _internalFocus,
                    autofocus: widget.autofocus,
                    readOnly: widget.readOnly,
                    onTap: widget.readOnly ? widget.onTap : null,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: AppColors.textMutedOf(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
                if (!widget.readOnly)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (_, val, __) => val.text.isNotEmpty
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textMutedOf(context),
                              size: 20,
                            ),
                            onPressed: () {
                              widget.controller.clear();
                              widget.onChanged?.call('');
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

