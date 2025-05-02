import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:takar/pages/Activities/activity.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final Color accentColor;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.accentColor,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit?.call(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/activityDetail', arguments: activity);
        },
        onLongPress: () {
          _showActionSheet(context);
        },
        child: Card(
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 40, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activity.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(activity.subtitle,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            value: activity.progress / 100,
                            strokeWidth: 3,
                            color: accentColor,
                            backgroundColor: accentColor.withOpacity(0.2),
                          ),
                        ),
                        Text('${activity.progress.toInt()}%',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tags (optional)
                if (activity.tags != null && activity.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: activity.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: accentColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: accentColor),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),

                // Date + Icons
                Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm, dd MMM').format(activity.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Icon(Icons.bar_chart, size: 18, color: accentColor),
                    const SizedBox(width: 16),
                    Icon(Icons.play_arrow, size: 24, color: accentColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Activity'),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Activity'),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
