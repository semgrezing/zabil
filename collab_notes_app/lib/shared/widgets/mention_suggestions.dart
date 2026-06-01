import 'package:flutter/material.dart';
import '../../features/groups/models/group_model.dart';
import '../../core/config/app_config.dart';
import '../theme/app_colors.dart';

class MentionSuggestions extends StatelessWidget {
  final List<GroupMemberModel> members;
  final String query;
  final String? currentUserId;
  final void Function(GroupMemberModel member) onSelect;

  const MentionSuggestions({
    super.key,
    required this.members,
    required this.query,
    required this.onSelect,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = members.where((m) {
      if (m.userId == currentUserId) return false;
      final q = query.toLowerCase();
      if (q.isEmpty) return true;
      return m.username.toLowerCase().contains(q) ||
          (m.displayName?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final member = filtered[i];
            return _MemberTile(member: member, onTap: () => onSelect(member));
          },
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMemberModel member;
  final VoidCallback onTap;

  const _MemberTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveUrl(member.avatarUrl);
    final initials = member.displayLabel.isNotEmpty
        ? member.displayLabel[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: AppColors.bg3,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (member.displayName != null &&
                      member.displayName!.trim().isNotEmpty)
                    Text(
                      member.displayName!,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    '@${member.username}',
                    style: const TextStyle(
                      color: AppColors.fgSoft,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiOrigin}$raw';
  }
}

/// Parses text containing @mentions and returns styled TextSpan.
/// Mentions are highlighted with accent color and tappable via WidgetSpan.
TextSpan buildMentionSpans({
  required String text,
  required TextStyle baseStyle,
  Color mentionColor = const Color(0xFF5B9EF4),
  void Function(String username)? onMentionTap,
}) {
  final mentionPattern = RegExp(r'@(\w+)');
  final matches = mentionPattern.allMatches(text).toList();

  if (matches.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final spans = <InlineSpan>[];
  var lastEnd = 0;

  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, match.start),
        style: baseStyle,
      ));
    }

    final username = match.group(1)!;
    if (onMentionTap != null) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onMentionTap(username),
          child: Text(
            '@$username',
            style: baseStyle.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ));
    } else {
      spans.add(TextSpan(
        text: '@$username',
        style: baseStyle.copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w600,
        ),
      ));
    }
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastEnd),
      style: baseStyle,
    ));
  }

  return TextSpan(children: spans);
}
