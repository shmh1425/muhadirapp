import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum AdminProfileRole { student, lecturer, security }

extension _AdminProfileRoleX on AdminProfileRole {
  String get labelAr {
    return switch (this) {
      AdminProfileRole.student => 'الطلاب',
      AdminProfileRole.lecturer => 'المحاضرين',
      AdminProfileRole.security => 'الأمن',
    };
  }

  String get collectionName {
    return switch (this) {
      AdminProfileRole.student => 'external_students',
      AdminProfileRole.lecturer => 'external_lecturers',
      AdminProfileRole.security => 'security_staff',
    };
  }

  String get storageFolder {
    return switch (this) {
      AdminProfileRole.student => 'external_students',
      AdminProfileRole.lecturer => 'external_lecturers',
      AdminProfileRole.security => 'security_staff',
    };
  }

  String get helperText {
    return switch (this) {
      AdminProfileRole.student =>
        'اختاري الطالبة ثم ارفعي الصورة. ستظهر في بروفايل الطالبة مباشرة.',
      AdminProfileRole.lecturer =>
        'اختاري المحاضِرة ثم ارفعي الصورة. ستنعكس في بروفايل المحاضرة.',
      AdminProfileRole.security =>
        'اختاري موظفة الأمن ثم ارفعي الصورة. ستظهر مباشرة في إعداداتها.',
    };
  }
}

class _AdminProfileUser {
  const _AdminProfileUser({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.photoUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String photoUrl;
}

class AdminProfileImageManagementTab extends StatefulWidget {
  const AdminProfileImageManagementTab({super.key});

  @override
  State<AdminProfileImageManagementTab> createState() =>
      _AdminProfileImageManagementTabState();
}

class _AdminProfileImageManagementTabState
    extends State<AdminProfileImageManagementTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  AdminProfileRole _selectedRole = AdminProfileRole.student;
  List<_AdminProfileUser> _users = const <_AdminProfileUser>[];
  String? _selectedUserId;

  bool _isLoadingUsers = false;
  bool _isUploading = false;

  _AdminProfileUser? _findUserById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final snapshot = await _firestore
          .collection(_selectedRole.collectionName)
          .get();
      final users =
          snapshot.docs
              .map((doc) => _mapDocToUser(doc.id, doc.data(), _selectedRole))
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));

      final currentSelectedExists = users.any((u) => u.id == _selectedUserId);
      setState(() {
        _users = users;
        if (!currentSelectedExists) {
          _selectedUserId = users.isNotEmpty ? users.first.id : null;
        }
      });
    } on FirebaseException catch (e) {
      _showMessage('تعذر تحميل القائمة: ${e.message ?? e.code}');
    } catch (_) {
      _showMessage('تعذر تحميل القائمة، حاولي مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  _AdminProfileUser _mapDocToUser(
    String docId,
    Map<String, dynamic> data,
    AdminProfileRole role,
  ) {
    String safe(dynamic value) => (value ?? '').toString().trim();
    String withVersion(String rawUrl, dynamic versionValue) {
      final url = rawUrl.trim();
      if (url.isEmpty) return '';
      final version = (versionValue ?? '').toString().trim();
      if (version.isEmpty) return url;
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}v=$version';
    }

    final rawPhotoUrl = safe(data['photoUrl']).isNotEmpty
        ? safe(data['photoUrl'])
        : safe(data['photoURL']);
    final photoUrl = withVersion(rawPhotoUrl, data['photoVersion']);

    if (role == AdminProfileRole.student) {
      final studentId = safe(data['studentId']).isNotEmpty
          ? safe(data['studentId'])
          : docId;
      final nameAr = safe(data['name_ar']);
      final nameEn = safe(data['name']);
      final email = safe(data['email']);
      final displayName = nameAr.isNotEmpty
          ? nameAr
          : (nameEn.isNotEmpty ? nameEn : 'طالبة بدون اسم');
      return _AdminProfileUser(
        id: docId,
        title: '$displayName ($studentId)',
        subtitle: email.isEmpty ? 'بدون بريد إلكتروني' : email,
        photoUrl: photoUrl,
      );
    }

    if (role == AdminProfileRole.lecturer) {
      final nameAr = safe(data['nameAr']);
      final nameEn = safe(data['nameEn']);
      final email = safe(data['email']);
      final displayName = nameAr.isNotEmpty
          ? nameAr
          : (nameEn.isNotEmpty ? nameEn : 'محاضرة بدون اسم');
      return _AdminProfileUser(
        id: docId,
        title: '$displayName ($docId)',
        subtitle: email.isEmpty ? 'بدون بريد إلكتروني' : email,
        photoUrl: photoUrl,
      );
    }

    final fullName = safe(data['fullName']);
    final name = safe(data['name']);
    final email = safe(data['email']);
    final displayName = fullName.isNotEmpty
        ? fullName
        : (name.isNotEmpty ? name : 'حساب أمن');
    return _AdminProfileUser(
      id: docId,
      title: '$displayName ($docId)',
      subtitle: email.isEmpty ? 'بدون بريد إلكتروني' : email,
      photoUrl: photoUrl,
    );
  }

  Future<void> _pickAndUploadImage() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      _showMessage('الجلسة غير صالحة. سجّلي دخول الأدمن مرة أخرى.');
      return;
    }

    if (_selectedUserId == null) {
      _showMessage('اختاري مستخدماً أولاً');
      return;
    }

    final user = _findUserById(_selectedUserId);
    if (user == null) {
      _showMessage('المستخدم المختار غير موجود حالياً');
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final extension = _normalizeExtension(pickedFile.name);
    final contentType = _contentTypeForExtension(extension);
    final storagePath =
        '${_selectedRole.storageFolder}/${user.id}/profile.$extension';

    setState(() => _isUploading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final storageRef = _storage.ref().child(storagePath);
      final photoVersion = DateTime.now().millisecondsSinceEpoch;

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      final payload = <String, dynamic>{
        'photoUrl': downloadUrl,
        'photoVersion': photoVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_selectedRole == AdminProfileRole.student) {
        payload['photoURL'] = downloadUrl;
      }

      await _firestore
          .collection(_selectedRole.collectionName)
          .doc(user.id)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _users = _users
            .map(
              (entry) => entry.id == user.id
                  ? _AdminProfileUser(
                      id: entry.id,
                      title: entry.title,
                      subtitle: entry.subtitle,
                      photoUrl: '$downloadUrl?v=$photoVersion',
                    )
                  : entry,
            )
            .toList();
      });
      _showMessage('تم رفع الصورة وتحديث البروفايل بنجاح');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        _showMessage(
          'رفض صلاحية الرفع. تأكدي من نشر Storage Rules ووجود حساب الأدمن في admins.',
        );
      } else {
        _showMessage('تعذر رفع الصورة: ${e.message ?? e.code}');
      }
    } catch (_) {
      _showMessage('تعذر رفع الصورة، حاولي مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _normalizeExtension(String fileName) {
    final lowered = fileName.trim().toLowerCase();
    final dot = lowered.lastIndexOf('.');
    if (dot == -1 || dot == lowered.length - 1) return 'jpeg';

    final ext = lowered.substring(dot + 1);
    if (ext == 'jpg') return 'jpeg';
    const supported = <String>{
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'heic',
      'heif',
    };
    return supported.contains(ext) ? ext : 'jpeg';
  }

  String _contentTypeForExtension(String ext) {
    return switch (ext) {
      'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedUser = _findUserById(_selectedUserId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'إدارة صور البروفايل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<AdminProfileRole>(
          key: ValueKey<AdminProfileRole>(_selectedRole),
          initialValue: _selectedRole,
          decoration: const InputDecoration(
            labelText: 'نوع المستخدم',
            border: OutlineInputBorder(),
          ),
          items: AdminProfileRole.values
              .map(
                (role) => DropdownMenuItem<AdminProfileRole>(
                  value: role,
                  child: Text(role.labelAr),
                ),
              )
              .toList(),
          onChanged: (role) {
            if (role == null) return;
            setState(() {
              _selectedRole = role;
              _selectedUserId = null;
              _users = const <_AdminProfileUser>[];
            });
            _loadUsers();
          },
        ),
        const SizedBox(height: 10),
        Text(
          _selectedRole.helperText,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (_isLoadingUsers) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            '${_selectedRole.name}-${_selectedUserId ?? 'none'}-${_users.length}',
          ),
          initialValue: _selectedUserId,
          decoration: const InputDecoration(
            labelText: 'اختيار المستخدم',
            border: OutlineInputBorder(),
          ),
          items: _users
              .map(
                (user) => DropdownMenuItem<String>(
                  value: user.id,
                  child: Text(user.title, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _users.isEmpty
              ? null
              : (value) {
                  setState(() => _selectedUserId = value);
                },
        ),
        if (_users.isEmpty && !_isLoadingUsers) ...[
          const SizedBox(height: 8),
          const Text(
            'لا توجد حسابات في هذا التصنيف حالياً.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 14),
        if (selectedUser != null)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE3F2F3),
                backgroundImage: selectedUser.photoUrl.isNotEmpty
                    ? NetworkImage(selectedUser.photoUrl)
                    : null,
                child: selectedUser.photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Color(0xFF006571))
                    : null,
              ),
              title: Text(selectedUser.title),
              subtitle: Text(selectedUser.subtitle),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isUploading || _selectedUserId == null
                    ? null
                    : _pickAndUploadImage,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploading ? 'جاري الرفع...' : 'رفع الصورة'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
            ),
          ],
        ),
      ],
    );
  }
}
