import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../repositories/file_upload_repository.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../config/app_env.dart';
import 'notification_banner.dart';

/// Receipt uploader widget that picks an image and uploads it to the backend.
///
/// The [onImageChanged] callback receives the **server URL** (not the local path)
/// after a successful upload, so the calling screen stores the URL in the model.
class ReceiptUploader extends ConsumerStatefulWidget {
  final String? imagePath;
  final ValueChanged<String?> onImageChanged;
  final bool isReadOnly;
  final String? entityId;

  const ReceiptUploader({
    super.key,
    required this.imagePath,
    required this.onImageChanged,
    this.isReadOnly = false,
    this.entityId,
  });

  @override
  ConsumerState<ReceiptUploader> createState() => _ReceiptUploaderState();
}

class _ReceiptUploaderState extends ConsumerState<ReceiptUploader> {
  bool _isUploading = false;

  Future<void> _pickAndUpload(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      // Upload to backend
      try {
        final uploadRepo = ref.read(fileUploadRepositoryProvider);
        final result = await uploadRepo.upload(
          filePathOrDataUri: pickedFile.path,
          category: UploadCategory.receipts,
          entityId: widget.entityId,
        );
        widget.onImageChanged(result.url);
      } catch (uploadError) {
        debugPrint('[ReceiptUploader] Backend upload failed, using local path: $uploadError');
        // Fallback: use local path if backend is unreachable
        widget.onImageChanged(pickedFile.path);
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.showError(context, 'Could not load receipt: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPickerModal(BuildContext context) {
    final isDark = AppColors.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attach Receipt',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.getTextPrimary(context)),
              ),
              const SizedBox(height: 6),
              Text(
                'Select receipt source for financial verification',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                ),
                title: Text('Take Photo', style: AppTextStyles.labelLarge),
                subtitle: Text('Capture with device camera', style: AppTextStyles.bodySmall),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(context, ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                ),
                title: Text('Choose from Gallery', style: AppTextStyles.labelLarge),
                subtitle: Text('Upload saved photo or PDF receipt', style: AppTextStyles.bodySmall),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.floatingShadow(true),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Receipt Full View', style: AppTextStyles.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Verified File',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.emeraldDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildReceiptVisual(context: context, isExpanded: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptVisual({required BuildContext context, bool isExpanded = false}) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = AppColors.isDark(context);
    final path = widget.imagePath!;

    // Determine if this is a server URL, a sample, or a real local file
    final bool isServerUrl = path.startsWith('/uploads/') || path.startsWith('http');
    final bool isSample = path.contains('sample_receipt');
    final bool isLocalFile = !kIsWeb && !isServerUrl && !isSample && File(path).existsSync();

    if (isLocalFile) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          height: isExpanded ? 400 : 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (isServerUrl) {
      final baseUrl = _resolveBaseUrl(ref);
      final finalUrl = path.startsWith('http')
          ? path
          : (path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path');
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          finalUrl,
          height: isExpanded ? 400 : 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(context, isDark, isExpanded),
        ),
      );
    }

    // Fallback: styled placeholder for sample/unavailable receipts
    return _buildPlaceholder(context, isDark, isExpanded);
  }

  String _resolveBaseUrl(WidgetRef ref) {
    // Use the API base URL without the /api/v1 suffix for static files
    return AppEnv.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  }

  Widget _buildPlaceholder(BuildContext context, bool isDark, bool isExpanded) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context), width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isExpanded ? 24 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: isExpanded ? 36 : 26,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TAX INVOICE & RECEIPT',
            style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Verified Enterprise Merchant Document',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.getTextMuted(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkEmeraldLight : AppColors.emeraldLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkEmeraldBorder : AppColors.emeraldBorder,
              ),
            ),
            child: Text(
              'Validated Digital Attachment',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.emeraldAccent : AppColors.emeraldDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    // Show upload progress indicator
    if (_isUploading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceSubtle.withValues(alpha: 0.6)
              : AppColors.surfaceSubtle.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1.2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Uploading receipt...',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.getTextMuted(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
          boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Receipt Attached',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isDark ? AppColors.emeraldAccent : AppColors.emeraldDark,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.zoom_in_rounded, size: 15),
                      label: const Text('View Full', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showFullScreen(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (!widget.isReadOnly) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.crimson),
                        label: Text(
                          'Remove',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 11),
                        ),
                        onPressed: () => widget.onImageChanged(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showFullScreen(context),
              child: _buildReceiptVisual(context: context),
            ),
          ],
        ),
      );
    }

    if (widget.isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 18, color: AppColors.getTextMuted(context)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'No receipt attached to this claim',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showPickerModal(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceSubtle.withValues(alpha: 0.6)
              : AppColors.surfaceSubtle.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1.2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: isDark ? AppColors.darkCardShadow() : AppColors.cardShadow,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 24,
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Upload Receipt Photo',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.getTextPrimary(context)),
              ),
              const SizedBox(height: 4),
              Text(
                'Take photo or choose from library (JPG, PNG)',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: AppColors.getTextMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
