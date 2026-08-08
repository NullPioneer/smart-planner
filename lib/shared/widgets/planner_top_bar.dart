import 'package:flutter/material.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';

class PlannerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PlannerTopBar({super.key, this.onMenu, this.onSearch});

  final VoidCallback? onMenu;
  final VoidCallback? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      leading: IconButton(
        key: const Key('open-side-menu'),
        tooltip: 'Open menu',
        onPressed: onMenu,
        icon: const Icon(Icons.menu_rounded),
      ),
      titleSpacing: 2,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/branding/smart_planner_logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Smart '),
                TextSpan(
                  text: 'Planner',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('global-search'),
          tooltip: 'Search',
          onPressed: onSearch,
          icon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
