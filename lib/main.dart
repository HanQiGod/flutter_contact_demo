import 'dart:convert';

import 'package:contactos/contactos.dart' as contactos;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker_plus/flutter_native_contact_picker_plus.dart'
    as native_picker;
import 'package:flutter_native_contact_picker_plus/model/contact_model.dart'
    as native_model;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ContactDemoApp());
}

class ContactDemoApp extends StatelessWidget {
  const ContactDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通讯录功能 Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F4),
      ),
      home: const ContactDemoHomePage(),
    );
  }
}

class ContactDemoHomePage extends StatelessWidget {
  const ContactDemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('通讯录功能 Demo'),
              Text(
                '原生选择器 + 完整通讯录读取与搜索',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '运行提示',
              onPressed: () => _showRunTips(context),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.contact_phone_outlined), text: '原生选择器'),
              Tab(icon: Icon(Icons.contacts_outlined), text: '完整通讯录'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [NativePickerDemoPage(), FullContactsDemoPage()],
        ),
      ),
    );
  }

  Future<void> _showRunTips(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: const [
              Text(
                '建议这样测试',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text('1. 优先使用 Android 或 iPhone 真机，模拟器通常没有真实联系人数据。'),
              Text('2. 先测试授权、拒绝、永久拒绝三种权限路径。'),
              Text('3. “添加示例联系人”会真的写入系统通讯录，只建议在测试机上使用。'),
            ],
          ),
        ),
      ),
    );
  }
}

class NativePickerDemoPage extends StatefulWidget {
  const NativePickerDemoPage({super.key});

  @override
  State<NativePickerDemoPage> createState() => _NativePickerDemoPageState();
}

class _NativePickerDemoPageState extends State<NativePickerDemoPage> {
  final native_picker.FlutterContactPickerPlus _contactPicker =
      native_picker.FlutterContactPickerPlus();

  native_model.Contact? _selectedContact;
  List<native_model.Contact> _selectedContacts = const [];
  bool _busy = false;
  String? _statusMessage;

  Future<void> _pickSingleContact() async {
    await _runAction(
      actionName: '选择联系人',
      action: () async {
        final status = await _ensureContactsPermission(
          context,
          purpose: '选择联系人并读取基本号码信息',
        );
        if (!_hasUsablePermission(status)) {
          _setStatus('未取得通讯录权限，已取消联系人选择。');
          return;
        }

        final contact = await _contactPicker.selectContact();
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedContact = contact;
          _selectedContacts = const [];
          _statusMessage = contact == null
              ? '用户取消了联系人选择。'
              : '已选择 ${_pickerContactName(contact)}。';
        });
      },
    );
  }

  Future<void> _pickPhoneNumber() async {
    await _runAction(
      actionName: '选择号码',
      action: () async {
        final status = await _ensureContactsPermission(
          context,
          purpose: '选择联系人中的某个手机号',
        );
        if (!_hasUsablePermission(status)) {
          _setStatus('未取得通讯录权限，已取消号码选择。');
          return;
        }

        final contact = await _contactPicker.selectPhoneNumber();
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedContact = contact;
          _selectedContacts = const [];
          _statusMessage = contact == null
              ? '用户取消了号码选择。'
              : '已选择 ${_pickerContactName(contact)} 的号码。';
        });
      },
    );
  }

  Future<void> _pickMultipleContacts() async {
    if (!_supportsIosMultiSelection) {
      _showSnackBar('多联系人选择仅 iOS 支持。');
      return;
    }

    await _runAction(
      actionName: '多联系人选择',
      action: () async {
        final status = await _ensureContactsPermission(
          context,
          purpose: '在 iOS 上一次选择多个联系人',
        );
        if (!_hasUsablePermission(status)) {
          _setStatus('未取得通讯录权限，已取消多选。');
          return;
        }

        final contacts = await _contactPicker.selectContacts();
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedContact = null;
          _selectedContacts = contacts ?? const [];
          _statusMessage = _selectedContacts.isEmpty
              ? '用户没有选择联系人。'
              : '已选择 ${_selectedContacts.length} 位联系人。';
        });
      },
    );
  }

  Future<void> _runAction({
    required String actionName,
    required Future<void> Function() action,
  }) async {
    if (!_supportsContactsDemo) {
      _showSnackBar('当前平台不支持通讯录插件，请在 Android 或 iOS 真机上测试。');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await action();
    } catch (error) {
      _setStatus('$actionName失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = message;
    });
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsContactsDemo) {
      return const _UnsupportedPlatformView(
        title: '当前平台不支持原生联系人选择器',
        description: '这个 demo 需要 Android 或 iOS 真机来调起系统通讯录界面。',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _IntroCard(
          icon: Icons.flash_on_rounded,
          title: '轻量级方案',
          description:
              '使用 flutter_native_contact_picker_plus 直接调起系统通讯录 UI，适合分享、转账、快速拨号这类只需要拿到一个联系人的场景。',
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Text(
                '操作演示',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickSingleContact,
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('选择联系人'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _pickPhoneNumber,
                    icon: const Icon(Icons.phone_enabled_outlined),
                    label: const Text('选择特定号码'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || !_supportsIosMultiSelection
                        ? null
                        : _pickMultipleContacts,
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(
                      _supportsIosMultiSelection ? 'iOS 多联系人' : 'iOS 专属',
                    ),
                  ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          _StatusCard(message: _statusMessage!),
        ],
        if (_selectedContact != null) ...[
          const SizedBox(height: 16),
          _PickerResultCard(contact: _selectedContact!),
        ],
        if (_selectedContacts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MultiplePickerResultCard(contacts: _selectedContacts),
        ],
        const SizedBox(height: 16),
        const _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(
                '实践建议',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text('1. 只需要选择一个联系人时，优先使用系统选择器，开发成本最低。'),
              Text('2. 权限要在用户点击功能时再请求，不要在 App 启动时就弹窗。'),
              Text('3. 如果用户永久拒绝权限，应该引导去系统设置，而不是重复弹请求。'),
            ],
          ),
        ),
      ],
    );
  }
}

class FullContactsDemoPage extends StatefulWidget {
  const FullContactsDemoPage({super.key});

  @override
  State<FullContactsDemoPage> createState() => _FullContactsDemoPageState();
}

class _FullContactsDemoPageState extends State<FullContactsDemoPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Uint8List> _avatarCache = <String, Uint8List>{};

  List<contactos.Contact> _contacts = const [];
  PermissionStatus? _permissionStatus;
  bool _loading = false;
  bool _withThumbnails = false;
  bool _hasLoadedOnce = false;
  String? _statusMessage;

  List<contactos.Contact> get _filteredContacts {
    final keyword = _normalizedText(_searchController.text)?.toLowerCase();
    if (keyword == null) {
      return _contacts;
    }

    return _contacts.where((contact) {
      final searchPool = [
        _contactDisplayName(contact),
        _normalizedText(contact.company),
        _normalizedText(contact.jobTitle),
        ...?contact.phones?.map((field) => _normalizedText(field.value)),
        ...?contact.emails?.map((field) => _normalizedText(field.value)),
      ].whereType<String>().map((value) => value.toLowerCase()).join('\n');

      return searchPool.contains(keyword);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (!_supportsContactsDemo) {
      _showSnackBar('当前平台不支持完整通讯录读取。');
      return;
    }

    setState(() {
      _loading = true;
    });

    final status = await _ensureContactsPermission(
      context,
      purpose: '在应用内读取完整通讯录列表',
    );
    if (!mounted) {
      return;
    }

    _permissionStatus = status;

    if (!_hasUsablePermission(status)) {
      setState(() {
        _loading = false;
        _hasLoadedOnce = true;
        _statusMessage = '未取得通讯录权限，无法读取完整列表。';
      });
      return;
    }

    try {
      final contacts = await contactos.Contactos.instance.getContacts(
        withThumbnails: _withThumbnails,
        photoHighResolution: _withThumbnails,
      );
      if (!mounted) {
        return;
      }

      final avatarCache = Map<String, Uint8List>.from(_avatarCache);
      if (_withThumbnails) {
        for (final contact in contacts) {
          final identifier = _normalizedText(contact.identifier);
          final avatar = contact.avatar;
          if (identifier != null && avatar != null) {
            avatarCache[identifier] = avatar;
          }
        }
      }

      setState(() {
        _contacts = contacts;
        _avatarCache
          ..clear()
          ..addAll(avatarCache);
        _loading = false;
        _hasLoadedOnce = true;
        _statusMessage = '已读取 ${contacts.length} 位联系人。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _hasLoadedOnce = true;
        _statusMessage = '读取通讯录失败：$error';
      });
    }
  }

  Future<void> _addDemoContact() async {
    if (!_supportsContactsDemo) {
      _showSnackBar('当前平台不支持联系人写入。');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('写入演示联系人'),
          content: const Text(
            '这一步会真实向系统通讯录新增一位名为 Flutter Demo 的联系人，只建议在测试机上执行。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续写入'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final status = await _ensureContactsPermission(
      context,
      purpose: '向系统通讯录写入演示联系人',
    );
    if (!_hasUsablePermission(status)) {
      setState(() {
        _permissionStatus = status;
        _statusMessage = '没有写入权限，已取消演示联系人创建。';
      });
      return;
    }

    final suffix = (DateTime.now().millisecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    final demoContact = contactos.Contact(
      givenName: 'Flutter',
      familyName: 'Demo $suffix',
      company: 'AI Project Lab',
      jobTitle: 'Contact Demo',
      phones: [
        contactos.Contact$Field(label: 'mobile', value: '1700000$suffix'),
      ],
      emails: [
        contactos.Contact$Field(
          label: 'work',
          value: 'flutter.demo.$suffix@example.com',
        ),
      ],
    );

    setState(() {
      _loading = true;
    });

    try {
      await contactos.Contactos.instance.addContact(demoContact);
      if (!mounted) {
        return;
      }
      _showSnackBar('示例联系人已写入系统通讯录。');
      await _loadContacts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _statusMessage = '新增联系人失败：$error';
      });
    }
  }

  Future<void> _openContactDetails(contactos.Contact contact) async {
    await _loadAvatar(contact, silent: true);
    if (!mounted) {
      return;
    }

    final avatar = _avatarFor(contact);
    final phones = contact.phones ?? const <contactos.Contact$Field>[];
    final emails = contact.emails ?? const <contactos.Contact$Field>[];
    final addresses =
        contact.postalAddresses ?? const <contactos.Contact$PostalAddress>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Row(
                    children: [
                      _Avatar(
                        bytes: avatar,
                        label: _contactDisplayName(contact),
                        radius: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _contactDisplayName(contact),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _contactSubtitle(contact) ?? '无公司或号码信息',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _DetailGroup(
                    title: '电话号码',
                    values: phones
                        .map(
                          (field) => _joinNonEmpty([
                            _normalizedText(field.value),
                            _normalizedText(field.label),
                          ], separator: ' · '),
                        )
                        .whereType<String>()
                        .toList(),
                    emptyLabel: '无号码',
                  ),
                  _DetailGroup(
                    title: '邮箱地址',
                    values: emails
                        .map(
                          (field) => _joinNonEmpty([
                            _normalizedText(field.value),
                            _normalizedText(field.label),
                          ], separator: ' · '),
                        )
                        .whereType<String>()
                        .toList(),
                    emptyLabel: '无邮箱',
                  ),
                  _DetailGroup(
                    title: '地址',
                    values: addresses
                        .map(
                          (address) => _joinNonEmpty([
                            _normalizedText(address.street),
                            _normalizedText(address.city),
                            _normalizedText(address.region),
                            _normalizedText(address.postcode),
                            _normalizedText(address.country),
                          ]),
                        )
                        .whereType<String>()
                        .toList(),
                    emptyLabel: '无地址',
                  ),
                  _DetailGroup(
                    title: '组织信息',
                    values: [
                      _joinNonEmpty([
                        _normalizedText(contact.company),
                        _normalizedText(contact.jobTitle),
                      ], separator: ' · '),
                    ].whereType<String>().toList(),
                    emptyLabel: '无组织信息',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAvatar(
    contactos.Contact contact, {
    bool silent = false,
  }) async {
    final identifier = _normalizedText(contact.identifier);
    if (identifier == null || _avatarCache.containsKey(identifier)) {
      return;
    }

    try {
      final avatar = await contactos.Contactos.instance.getAvatar(
        contact,
        photoHighRes: false,
      );
      if (!mounted || avatar == null) {
        return;
      }

      setState(() {
        _avatarCache[identifier] = avatar;
      });
    } catch (error) {
      if (!silent) {
        _showSnackBar('加载联系人头像失败：$error');
      }
    }
  }

  Uint8List? _avatarFor(contactos.Contact contact) {
    final identifier = _normalizedText(contact.identifier);
    if (identifier == null) {
      return contact.avatar;
    }

    return _avatarCache[identifier] ?? contact.avatar;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsContactsDemo) {
      return const _UnsupportedPlatformView(
        title: '当前平台不支持完整通讯录读取',
        description: '请在 Android 或 iOS 真机上测试 contactos 的读取、搜索和写入能力。',
      );
    }

    final filteredContacts = _filteredContacts;

    return RefreshIndicator(
      onRefresh: _hasLoadedOnce ? _loadContacts : () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 1 + (_buildListItemCount(filteredContacts)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IntroCard(
                  icon: Icons.dataset_linked_outlined,
                  title: '完整通讯录方案',
                  description:
                      '使用 contactos 读取联系人列表、自定义展示 UI、做本地搜索，并在需要时写入演示联系人。',
                ),
                const SizedBox(height: 16),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _loading ? null : _loadContacts,
                                  icon: const Icon(Icons.download_rounded),
                                  label: Text(
                                    _hasLoadedOnce ? '刷新通讯录' : '读取通讯录',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _loading ? null : _addDemoContact,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('添加示例联系人'),
                                ),
                              ],
                            ),
                          ),
                          _PermissionBadge(status: _permissionStatus),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('读取时同时加载头像'),
                        subtitle: const Text('关闭后首次加载更快，点击联系人时再按需获取头像。'),
                        value: _withThumbnails,
                        onChanged: (value) {
                          setState(() {
                            _withThumbnails = value;
                          });
                          if (_hasLoadedOnce && !_loading) {
                            _loadContacts();
                          }
                        },
                      ),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '按姓名、手机号、邮箱搜索',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空搜索',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const Text('提示：写入联系人会真实落到系统通讯录，建议只在测试设备上演示。'),
                      if (_loading) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  _StatusCard(message: _statusMessage!),
                ],
                const SizedBox(height: 16),
                _SummaryCard(
                  totalCount: _contacts.length,
                  visibleCount: filteredContacts.length,
                  hasLoadedOnce: _hasLoadedOnce,
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          if (!_hasLoadedOnce) {
            return const _EmptyStateCard(
              title: '还没有读取通讯录',
              description: '点击“读取通讯录”后，就会在这里显示联系人列表和搜索结果。',
            );
          }

          if (filteredContacts.isEmpty) {
            return const _EmptyStateCard(
              title: '没有匹配结果',
              description: '请更换搜索关键字，或者重新刷新通讯录。',
            );
          }

          final contact = filteredContacts[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ContactTile(
              contact: contact,
              avatar: _avatarFor(contact),
              onTap: () => _openContactDetails(contact),
            ),
          );
        },
      ),
    );
  }

  int _buildListItemCount(List<contactos.Contact> filteredContacts) {
    if (!_hasLoadedOnce || filteredContacts.isEmpty) {
      return 1;
    }

    return filteredContacts.length;
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    height: 1.5,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _PickerResultCard extends StatelessWidget {
  const _PickerResultCard({required this.contact});

  final native_model.Contact contact;

  @override
  Widget build(BuildContext context) {
    final avatarBytes = _decodeBase64Avatar(contact.avatar);
    final organization = _joinNonEmpty([
      _normalizedText(contact.organizationInfo?.company),
      _normalizedText(contact.organizationInfo?.jobTitle),
    ], separator: ' · ');

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            children: [
              _Avatar(
                bytes: avatarBytes,
                label: _pickerContactName(contact),
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pickerContactName(contact),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      organization ?? '来自系统原生联系人选择器',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _DetailGroup(
            title: '已选号码',
            values: [
              _normalizedText(contact.selectedPhoneNumber),
            ].whereType<String>().toList(),
            emptyLabel: '本次没有单独选择号码',
          ),
          _DetailGroup(
            title: '全部号码',
            values: (contact.phoneNumbers ?? const <String>[])
                .map(_normalizedText)
                .whereType<String>()
                .toList(),
            emptyLabel: '无号码',
          ),
          _DetailGroup(
            title: '邮箱地址',
            values:
                (contact.emailAddresses ?? const <native_model.EmailAddress>[])
                    .map(
                      (item) => _joinNonEmpty([
                        _normalizedText(item.email),
                        _normalizedText(item.label),
                      ], separator: ' · '),
                    )
                    .whereType<String>()
                    .toList(),
            emptyLabel: '无邮箱',
          ),
          _DetailGroup(
            title: '地址',
            values:
                (contact.postalAddresses ??
                        const <native_model.PostalAddress>[])
                    .map(
                      (item) => _joinNonEmpty([
                        _normalizedText(item.street),
                        _normalizedText(item.city),
                        _normalizedText(item.state),
                        _normalizedText(item.postalCode),
                        _normalizedText(item.country),
                      ]),
                    )
                    .whereType<String>()
                    .toList(),
            emptyLabel: '无地址',
          ),
        ],
      ),
    );
  }
}

class _MultiplePickerResultCard extends StatelessWidget {
  const _MultiplePickerResultCard({required this.contacts});

  final List<native_model.Contact> contacts;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Text(
            '多联系人选择结果（${contacts.length}）',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          ...contacts.map(
            (contact) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(label: _pickerContactName(contact), radius: 22),
              title: Text(_pickerContactName(contact)),
              subtitle: Text(
                _joinNonEmpty(
                      (contact.phoneNumbers ?? const <String>[])
                          .map(_normalizedText)
                          .whereType<String>()
                          .toList(),
                      separator: ' · ',
                    ) ??
                    '无号码',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.visibleCount,
    required this.hasLoadedOnce,
  });

  final int totalCount;
  final int visibleCount;
  final bool hasLoadedOnce;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: '总联系人',
              value: hasLoadedOnce ? '$totalCount' : '--',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryMetric(
              label: '当前结果',
              value: hasLoadedOnce ? '$visibleCount' : '--',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.avatar,
    required this.onTap,
  });

  final contactos.Contact contact;
  final Uint8List? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _Avatar(
          bytes: avatar,
          label: _contactDisplayName(contact),
          radius: 24,
        ),
        title: Text(_contactDisplayName(contact)),
        subtitle: Text(_contactSubtitle(contact) ?? '无号码'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _PermissionBadge extends StatelessWidget {
  const _PermissionBadge({required this.status});

  final PermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, backgroundColor, foregroundColor) = switch (status) {
      null => (
        '未请求',
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
      PermissionStatus.granted => (
        '已授权',
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      PermissionStatus.limited => (
        '部分授权',
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      PermissionStatus.permanentlyDenied => (
        '永久拒绝',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      PermissionStatus.restricted => (
        '系统限制',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
      _ => (
        '已拒绝',
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: foregroundColor),
      ),
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({
    required this.title,
    required this.values,
    required this.emptyLabel,
  });

  final String title;
  final List<String> values;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (values.isEmpty)
          Text(
            emptyLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (value) => Chip(
                    label: Text(value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.bytes, required this.label, this.radius = 24});

  final Uint8List? bytes;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes!));
    }

    return CircleAvatar(
      radius: radius,
      child: Text(
        _initials(label),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(description),
        ],
      ),
    );
  }
}

class _UnsupportedPlatformView extends StatelessWidget {
  const _UnsupportedPlatformView({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Icon(Icons.phonelink_erase_rounded, size: 32),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

Future<PermissionStatus> _ensureContactsPermission(
  BuildContext context, {
  required String purpose,
}) async {
  var status = await Permission.contacts.status;

  if (status.isDenied) {
    status = await Permission.contacts.request();
  }

  if (!context.mounted) {
    return status;
  }

  if (status.isPermanentlyDenied || status.isRestricted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('需要通讯录权限'),
          content: Text('为了$purpose，请在系统设置里打开通讯录权限。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  } else if (status.isDenied) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('未取得通讯录权限，无法$purpose。')));
  }

  return status;
}

bool get _supportsContactsDemo =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get _supportsIosMultiSelection =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool _hasUsablePermission(PermissionStatus? status) {
  if (status == null) {
    return false;
  }

  return status.isGranted || status.isLimited;
}

String _pickerContactName(native_model.Contact contact) {
  return _normalizedText(contact.fullName) ?? '未命名联系人';
}

String _contactDisplayName(contactos.Contact contact) {
  return _normalizedText(contact.displayName) ??
      _joinNonEmpty([
        _normalizedText(contact.givenName),
        _normalizedText(contact.familyName),
      ]) ??
      '未命名联系人';
}

String? _contactSubtitle(contactos.Contact contact) {
  return _joinNonEmpty([
    _normalizedText(contact.company),
    _normalizedText(contact.jobTitle),
    contact.phones
        ?.map((field) => _normalizedText(field.value))
        .whereType<String>()
        .firstOrNull,
  ], separator: ' · ');
}

String? _normalizedText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }

  return text;
}

String? _joinNonEmpty(List<String?> values, {String separator = ' '}) {
  final normalized = values
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized.join(separator);
}

Uint8List? _decodeBase64Avatar(String? base64Value) {
  final raw = _normalizedText(base64Value);
  if (raw == null) {
    return null;
  }

  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

String _initials(String label) {
  final normalized = _normalizedText(label) ?? '';
  if (normalized.isEmpty) {
    return 'C';
  }

  final parts = normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${_firstSymbol(parts.first)}${_firstSymbol(parts.last)}'
        .toUpperCase();
  }

  return _takeSymbols(parts.first, 2).toUpperCase();
}

String _firstSymbol(String value) {
  if (value.isEmpty) {
    return '';
  }
  return String.fromCharCodes(value.runes.take(1));
}

String _takeSymbols(String value, int count) {
  if (value.isEmpty || count <= 0) {
    return '';
  }
  return String.fromCharCodes(value.runes.take(count));
}
