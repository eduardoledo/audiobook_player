import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

enum LibraryFilter { all, inProgress, completed }

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final LibraryFilter currentFilter;
  final ValueChanged<LibraryFilter> onFilterChanged;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeholder = l10n?.searchPlaceholder ?? 'Search by title, author, saga...';
    final allText = l10n?.filterAll ?? 'All';
    final inProgressText = l10n?.filterInProgress ?? 'In Progress';
    final completedText = l10n?.filterCompleted ?? 'Completed';

    return Container(
      color: const Color(0xFF252525),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B86D), size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(allText, LibraryFilter.all),
              const SizedBox(width: 8),
              _buildFilterChip(inProgressText, LibraryFilter.inProgress),
              const SizedBox(width: 8),
              _buildFilterChip(completedText, LibraryFilter.completed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LibraryFilter filter) {
    final isSelected = currentFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFE8B86D),
      backgroundColor: const Color(0xFF1E1E1E),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onFilterChanged(filter),
    );
  }
}
