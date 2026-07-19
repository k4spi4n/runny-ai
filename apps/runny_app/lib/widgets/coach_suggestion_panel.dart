import 'package:flutter/material.dart';

/// Một khả năng của HLV AI đi kèm câu hỏi mẫu có thể gửi ngay.
class CoachSuggestionItem {
  const CoachSuggestionItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.prompt,
    required this.accentColor,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final String prompt;
  final Color accentColor;
}

class CoachKnowledgePrompt {
  const CoachKnowledgePrompt({required this.id, required this.prompt});

  final String id;
  final String prompt;
}

/// Giới thiệu khả năng của HLV đồng thời đưa ra câu hỏi mẫu để bắt đầu chat.
class CoachSuggestionPanel extends StatelessWidget {
  const CoachSuggestionPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onSelected,
    required this.knowledgeTitle,
    required this.knowledgePrompts,
    required this.onKnowledgeSelected,
    required this.refreshTooltip,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final List<CoachSuggestionItem> items;
  final ValueChanged<CoachSuggestionItem> onSelected;
  final String knowledgeTitle;
  final List<CoachKnowledgePrompt> knowledgePrompts;
  final ValueChanged<CoachKnowledgePrompt> onKnowledgeSelected;
  final String refreshTooltip;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 4 : 16,
                isCompact ? 4 : 8,
                isCompact ? 4 : 16,
                isCompact ? 8 : 16,
              ),
              child: Material(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.78),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isCompact ? 36 : 40,
                            height: isCompact ? 36 : 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                isCompact ? 11 : 13,
                              ),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: isCompact ? 19 : 21,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: isCompact ? 10 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: isCompact ? 2 : null,
                                  overflow: isCompact
                                      ? TextOverflow.ellipsis
                                      : null,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('refresh_coach_suggestions'),
                            onPressed: onRefresh,
                            tooltip: refreshTooltip,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 12 : 16),
                      if (isCompact)
                        LayoutBuilder(
                          builder: (context, cardConstraints) {
                            return SizedBox(
                              key: const ValueKey(
                                'coach_suggestion_mobile_list',
                              ),
                              height: 132,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return SizedBox(
                                    width: cardConstraints.maxWidth * 0.84,
                                    child: _CoachSuggestionCard(
                                      item: item,
                                      onTap: () => onSelected(item),
                                      compact: true,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 148,
                              ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CoachSuggestionCard(
                              item: item,
                              onTap: () => onSelected(item),
                            );
                          },
                        ),
                      if (knowledgePrompts.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 14 : 18),
                        Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        SizedBox(height: isCompact ? 10 : 14),
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 19,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              knowledgeTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        if (isCompact)
                          SizedBox(
                            key: const ValueKey('coach_knowledge_mobile_list'),
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: knowledgePrompts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => _KnowledgeChip(
                                item: knowledgePrompts[index],
                                onSelected: onKnowledgeSelected,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: knowledgePrompts
                                .map(
                                  (item) => _KnowledgeChip(
                                    item: item,
                                    onSelected: onKnowledgeSelected,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KnowledgeChip extends StatelessWidget {
  const _KnowledgeChip({required this.item, required this.onSelected});

  final CoachKnowledgePrompt item;
  final ValueChanged<CoachKnowledgePrompt> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ActionChip(
      key: ValueKey('coach_knowledge_${item.id}'),
      avatar: Icon(
        Icons.lightbulb_outline_rounded,
        size: 17,
        color: colorScheme.primary,
      ),
      label: Text(item.prompt),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.32),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: () => onSelected(item),
    );
  }
}

class _CoachSuggestionCard extends StatelessWidget {
  const _CoachSuggestionCard({
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  final CoachSuggestionItem item;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '${item.title}: ${item.prompt}',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: item.accentColor.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('coach_suggestion_${item.id}'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 18, color: item.accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  item.description,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        item.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: item.accentColor,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: item.accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
