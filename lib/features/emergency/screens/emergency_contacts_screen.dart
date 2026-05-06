import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final user = await AuthService.loadUser();
    if (user != null) {
      final contacts = await LocalBackendService.getEmergencyContacts(user.id);
      if (mounted) setState(() { _contacts = contacts; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
          const SizedBox(height: 8),
          TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (optional)', hintText: 'e.g. Parent, Friend, Embassy')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              final user = await AuthService.loadUser();
              await LocalBackendService.addEmergencyContact(
                userId: user?.id ?? 'guest', name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(),
                relationship: relCtrl.text.trim().isEmpty ? null : relCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              _loadContacts();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadContacts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                    Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.emergency, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No emergency contacts', style: TextStyle(color: AppColors.textSecondary)),
                      const Text('Add contacts for your safety', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ])),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    itemBuilder: (_, i) {
                      final c = _contacts[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.person, color: Colors.red)),
                          title: Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${c['phone'] ?? ''}${c['relationship'] != null ? ' · ${c['relationship']}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _callNumber(c['phone'] as String? ?? '')),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async {
                              await LocalBackendService.deleteEmergencyContact(c['id'] as String);
                              _loadContacts();
                            }),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, backgroundColor: Colors.red, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}
