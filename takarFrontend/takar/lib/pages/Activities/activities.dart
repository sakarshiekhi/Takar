import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ActivitiesPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ActivitiesPage({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  _ActivitiesPageState createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('activities');
    if (data != null) {
      setState(() {
        _activities = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activities', jsonEncode(_activities));
  }

  void _addActivity(String title) {
    setState(() {
      _activities.add({"title": title, "done": false});
    });
    _saveActivities();
  }

  void _editActivity(int index, String newTitle) {
    setState(() {
      _activities[index]['title'] = newTitle;
    });
    _saveActivities();
  }

  void _deleteActivity(int index) {
    setState(() {
      _activities.removeAt(index);
    });
    _saveActivities();
  }

  void _toggleDone(int index, bool? value) {
    setState(() {
      _activities[index]['done'] = value ?? false;
    });
    _saveActivities();
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Activity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter activity title'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addActivity(controller.text.trim());
              }
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final controller = TextEditingController(text: _activities[index]['title']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Activity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Edit activity title'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _editActivity(index, controller.text.trim());
              }
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Account') {
                // TODO: Handle Account action
              } else if (value == 'Toggle Theme') {
                widget.onToggleTheme();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Account',
                child: Text('Account'),
              ),
              const PopupMenuItem(
                value: 'Toggle Theme',
                child: Text('Toggle Theme'),
              ),
            ],
            icon: Icon(Icons.more_vert, color: themeColor),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: themeColor.withOpacity(0.3), thickness: 1),
          ),
        ),
      ),
      body: _activities.isEmpty
          ? Center(
              child: Text(
                'No activities yet!',
                style: TextStyle(color: themeColor.withOpacity(0.6)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: activity['done'],
                      onChanged: (value) => _toggleDone(index, value),
                    ),
                    title: Text(
                      activity['title'],
                      style: TextStyle(
                        color: themeColor,
                        decoration: activity['done']
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'Edit') {
                          _showEditDialog(index);
                        } else if (value == 'Delete') {
                          _deleteActivity(index);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'Edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'Delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
