import 'package:flutter/material.dart';

class CompetitionFilterWidget extends StatelessWidget {
  final String currentFilter;
  final Function(String) onFilterChanged;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  const CompetitionFilterWidget({
    Key? key,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.searchController,
    required this.onSearchChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: '搜索比賽名稱',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),

          // 過濾選項
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, '全部'),
                _buildFilterChip(context, '計劃中'),
                _buildFilterChip(context, '進行中'),
                _buildFilterChip(context, '已結束'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 構建過濾選項
  Widget _buildFilterChip(BuildContext context, String label) {
    final isSelected = currentFilter == label;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            onFilterChanged(label);
          }
        },
        backgroundColor: Colors.white,
        selectedColor: theme.primaryColor.withOpacity(0.2),
        checkmarkColor: theme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? theme.primaryColor : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
