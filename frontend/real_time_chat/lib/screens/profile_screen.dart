import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/avatar_picker.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  UserModel? _currentUser;
  PickedAvatar? _pendingAvatar;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = await _authService.getProfile();
    if (mounted && user != null) {
      setState(() {
        _currentUser = user;
        _usernameController.text = user.username;
        _emailController.text = user.email;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateProfile() async {
    final newUsername = _usernameController.text.trim();
    final newEmail = _emailController.text.trim();
    if (newUsername.isEmpty || newEmail.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final updatedUser = await _authService.updateProfile(
        username: newUsername,
        email: newEmail,
        avatarBytes: _pendingAvatar?.bytes,
        avatarFileName: _pendingAvatar?.fileName,
        avatarMimeType: _pendingAvatar?.mimeType,
      );
      if (!mounted) return;
      if (updatedUser != null) {
        setState(() {
          _currentUser = updatedUser;
          _pendingAvatar = null;
        });
        _showSnackBar('Profil başarıyla güncellendi.', AppTheme.primary);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceAll('Exception: ', ''),
        Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePickAvatar() async {
    if (_isSaving || _isPickingAvatar) return;
    if (!avatarPickerSupported) {
      _showSnackBar(
        'Bu ortamda dosya seçme henüz aktif değil. Web görünümünde deneyebilirsin.',
        Colors.orangeAccent,
      );
      return;
    }

    setState(() => _isPickingAvatar = true);
    try {
      final picked = await pickAvatarImage();
      if (!mounted || picked == null) return;
      setState(() => _pendingAvatar = picked);
      _showSnackBar(
        'Fotoğraf seçildi. Kaydet butonuyla profilini güncelleyebilirsin.',
        AppTheme.primary,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Fotoğraf seçilemedi.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final surface = AppTheme.surface(dialogContext);
        final textPrimary = AppTheme.textPrimary(dialogContext);
        final textSecondary = AppTheme.textSecondary(dialogContext);
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Oturumu kapatmak istiyor musun?',
            style: TextStyle(color: textPrimary),
          ),
          content: Text(
            'Çıkış yaparsan yeniden giriş yapman gerekecek.',
            style: TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Vazgeç', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Çıkış Yap'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leftBg = AppTheme.leftPanelBg(context);
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final avatarProvider = _buildAvatarProvider();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_currentUser == null) {
      return Center(
        child: Text(
          'Profil yüklenemedi.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profil',
            style: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hesap bilgilerini düzenle, fotoğrafını güncelle ve görünümünü kişiselleştir.',
            style: TextStyle(color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          // WhatsApp Avatar Section
          Center(
            child: Stack(
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: avatarProvider != null
                        ? Image(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                            width: 130,
                            height: 130,
                            errorBuilder: (_, _, _) => _buildAvatarFallback(),
                          )
                        : _buildAvatarFallback(),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handlePickAvatar,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isPickingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fotoğrafını değiştirmek için kamera ikonuna dokun.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          if (_pendingAvatar != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Yeni fotoğraf hazır, kaydetmeyi unutma',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),

          Container(
            decoration: BoxDecoration(
              color: leftBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                // Profile Name Field
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: border, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kullanıcı Adı',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                // Email Field
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'E-Posta Adresi',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textPrimary, fontSize: 16),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Save Changes Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isSaving ? null : _handleUpdateProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Profili Kaydet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 16),

          // Logout Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text(
              'Çıkış Yap',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _buildAvatarProvider() {
    if (_pendingAvatar != null) {
      return MemoryImage(_pendingAvatar!.bytes);
    }
    final avatar = _currentUser?.avatar;
    if (avatar == null || avatar.isEmpty) return null;
    return NetworkImage(avatar);
  }

  Widget _buildAvatarFallback() => Center(
    child: Text(
      _currentUser!.username.isNotEmpty
          ? _currentUser!.username[0].toUpperCase()
          : 'U',
      style: const TextStyle(
        fontSize: 52,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
