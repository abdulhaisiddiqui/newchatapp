import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactSharePage extends StatefulWidget {
  const ContactSharePage({super.key});

  @override
  State<ContactSharePage> createState() => _ContactSharePageState();
}

class _ContactSharePageState extends State<ContactSharePage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _statusMessage = 'Loading contacts...';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Requesting contacts permission...';
      });

      // Request contacts permission
      final permissionStatus = await Permission.contacts.request();

      if (permissionStatus.isGranted) {
        setState(() => _statusMessage = 'Loading contacts...');

        // Load contacts
        final contacts = await FlutterContacts.getContacts(
          withProperties: true, // Load phone numbers and other properties
          withPhoto: false, // Don't load photos for performance
        );

        // Filter out contacts without names or phones
        final validContacts = contacts.where((contact) {
          final hasName = contact.displayName?.isNotEmpty ?? false;
          final hasPhones = contact.phones?.isNotEmpty ?? false;
          return hasName && hasPhones;
        }).toList();

        // Sort contacts alphabetically
        validContacts.sort(
          (a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''),
        );

        setState(() {
          _contacts = validContacts;
          _filteredContacts = validContacts;
          _isLoading = false;
        });
      } else if (permissionStatus.isPermanentlyDenied) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Contacts permission permanently denied. Please enable in app settings.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Contacts permission denied. Please grant permission to share contacts.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading contacts: ${e.toString()}';
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredContacts = _contacts);
    } else {
      setState(() {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName?.toLowerCase() ?? '';
          final phones = contact.phones;
          final phoneNumbers = phones
              .map((phone) => phone.number.toLowerCase())
              .join(' ');

          return name.contains(query) || phoneNumbers.contains(query);
        }).toList();
      });
    }
  }

  void _selectContact(Contact contact) {
    final phone = contact.phones?.isNotEmpty == true
        ? contact.phones!.first.number
        : null;

    Navigator.pop(context, {
      'name': contact.displayName ?? 'Unknown Contact',
      'phone': phone,
    });
  }

  Widget _buildContactAvatar(Contact contact) {
    final initials = contact.displayName?.isNotEmpty == true
        ? contact.displayName!
              .split(' ')
              .map((name) => name.isNotEmpty ? name[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return CircleAvatar(
      backgroundColor: Colors.blue.withOpacity(0.2),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contact'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Contacts list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_statusMessage.contains('permission'))
                          ElevatedButton(
                            onPressed: _loadContacts,
                            child: const Text('Try Again'),
                          ),
                      ],
                    ),
                  )
                : _filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No contacts found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final phone = contact.phones?.isNotEmpty == true
                          ? contact.phones!.first.number ?? 'No number'
                          : 'No number';

                      return ListTile(
                        leading: _buildContactAvatar(contact),
                        title: Text(
                          contact.displayName ?? 'Unknown Contact',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          phone,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        onTap: () => _selectContact(contact),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
