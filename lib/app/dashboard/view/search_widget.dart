import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomSearchBar extends StatelessWidget {
  const CustomSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFocus,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) onFocus();
              },
              child: CustomTextField(
                controller: controller,
                hintText: 'Enter new destination',
                onChanged: (v) {
                  onChanged(v);
                  onFocus();
                },
                prefix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 45,
                      width: 45,
                      child: AppIcon(
                        Assets.icons.searchGlass,
                        color: styles.theme.grey,
                        size: 18,
                      ),
                    ),
                    Text(
                      '|',
                      style: styles.typography.h4.textColor(styles.theme.ash),
                    ),
                  ],
                ),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: onClear,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.clear, color: Colors.black54),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () {
                        // Map action
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchSuggestion {
  SearchSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.distanceMeters,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final int distanceMeters;
}

class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({
    required this.suggestions,
    required this.onTap,
    super.key,
  });
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.red[100]),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.black54),
          title: Text(
            suggestion.mainText,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(suggestion.secondaryText),
          trailing: Text(
              suggestion.distanceMeters > 1000
                  ? '${(suggestion.distanceMeters / 1000).toStringAsFixed(1)} km'
                  : '${suggestion.distanceMeters} m',
              style: Theme.of(context).textTheme.bodyMedium),
          onTap: () => onTap(suggestion),
        );
      },
    );
  }
}
