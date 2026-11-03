import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

/// Hộp thoại cấu hình IP/Endpoint máy chủ PanelForge Backend (.NET 8)
class ServerConfigDialog extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  const ServerConfigDialog({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (context) => ServerConfigDialog(onSaved: onSaved),
    );
  }

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late final TextEditingController _ipController;
  bool _isChecking = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: ApiConfig.baseUrl);
    _checkConnection();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);
    try {
      final client = ApiClient();
      final res = await client.get('/api/catalog/series?pageIndex=1&pageSize=1');
      if (mounted) {
        setState(() {
          _isConnected = res.statusCode == 200;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      title: Text(
        'Cấu Hình Máy Chủ',
        style: GoogleFonts.newsreader(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Địa chỉ máy chủ API:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              hintText: 'http://10.0.2.2:5044',
              hintStyle: const TextStyle(color: Colors.white38),
              isDense: true,
            ),
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_isChecking)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: (_isConnected == true) ? AppColors.mint : AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _isChecking
                    ? 'Đang kiểm tra kết nối...'
                    : (_isConnected == true
                        ? 'Đã kết nối máy chủ'
                        : 'Chưa có kết nối máy chủ'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (_isConnected == true) ? AppColors.mint : AppColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            await PreferencesService.setCustomBaseUrl(_ipController.text.trim());
            if (context.mounted) Navigator.of(context).pop();
            widget.onSaved?.call();
          },
          child: const Text('Lưu & Thử kết nối'),
        ),
      ],
    );
  }
}

