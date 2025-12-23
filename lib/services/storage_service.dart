import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Storage service for managing files in Supabase Storage
class StorageService {
  final Dio _dio;

  StorageService(this._dio);

  // ================================================
  // PRODUCT IMAGES
  // ================================================

  /// Upload product image
  /// Returns the storage path
  Future<String> uploadProductImage({
    required String shopId,
    required String productId,
    required File imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = p.basename(imageFile.path);
      final ext = p.extension(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$shopId/$productId/${timestamp}_$fileName';

      // Upload to Supabase Storage with metadata for RLS
      await SupabaseService.storage
          .from('product_images')
          .upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      debugPrint('✅ Uploaded product image: $storagePath');
      return storagePath;
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      rethrow;
    }
  }

  /// Get public URL for product image
  String getProductImageUrl(String storagePath) {
    return SupabaseService.storage
        .from('product_images')
        .getPublicUrl(storagePath);
  }

  /// Delete product image
  Future<void> deleteProductImage(String storagePath) async {
    try {
      await SupabaseService.storage.from('product_images').remove([
        storagePath,
      ]);

      debugPrint('Deleted product image: $storagePath');
    } catch (e) {
      debugPrint('Error deleting product image: $e');
      rethrow;
    }
  }

  // ================================================
  // RECEIPTS
  // ================================================

  /// Upload receipt scan/photo
  Future<String> uploadReceipt({
    required String shopId,
    required String orderId,
    required File receiptFile,
    Function(double)? onProgress,
  }) async {
    try {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final fileName = p.basename(receiptFile.path);
      final ext = p.extension(fileName);
      final timestamp = now.millisecondsSinceEpoch;

      final storagePath =
          '$shopId/$year/$month/$orderId/${timestamp}_$fileName';

      // Upload with metadata for RLS
      await SupabaseService.storage
          .from('receipts')
          .upload(
            storagePath,
            receiptFile,
            fileOptions: const FileOptions(upsert: true),
          );

      debugPrint('✅ Uploaded receipt: $storagePath');
      return storagePath;
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      rethrow;
    }
  }

  /// Get signed URL for receipt (private bucket)
  Future<String> getReceiptSignedUrl(
    String storagePath, {
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    try {
      final signedUrl = await SupabaseService.storage
          .from('receipts')
          .createSignedUrl(storagePath, expiresIn.inSeconds);

      return signedUrl;
    } catch (e) {
      debugPrint('Error getting signed URL for receipt: $e');
      rethrow;
    }
  }

  /// Delete receipt
  Future<void> deleteReceipt(String storagePath) async {
    try {
      await SupabaseService.storage.from('receipts').remove([storagePath]);

      debugPrint('Deleted receipt: $storagePath');
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      rethrow;
    }
  }

  // ================================================
  // EXPORTS (CSV/JSON)
  // ================================================

  /// Upload export file
  Future<String> uploadExport({
    required String shopId,
    required File exportFile,
    required String exportType, // 'products', 'orders', 'customers', etc.
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(exportFile.path);
      final storagePath = '$shopId/exports/${timestamp}_$exportType$ext';

      // Upload with metadata for RLS
      await SupabaseService.storage
          .from('exports')
          .upload(
            storagePath,
            exportFile,
            fileOptions: const FileOptions(upsert: true),
          );

      debugPrint('✅ Uploaded export: $storagePath');
      return storagePath;
    } catch (e) {
      debugPrint('Error uploading export: $e');
      rethrow;
    }
  }

  /// Create and upload export, then return signed URL for sharing
  Future<ExportResult> createExportAndShare({
    required String shopId,
    required String exportType,
    required String content,
    required String format, // 'csv' or 'json'
    Duration expiresIn = const Duration(days: 7),
  }) async {
    try {
      // Create temporary file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$exportType.$format';
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsString(content);

      // Upload to storage
      final storagePath = await uploadExport(
        shopId: shopId,
        exportFile: tempFile,
        exportType: exportType,
      );

      // Get signed URL for sharing
      final signedUrl = await SupabaseService.storage
          .from('exports')
          .createSignedUrl(storagePath, expiresIn.inSeconds);

      // Clean up temp file
      await tempFile.delete();

      return ExportResult(
        storagePath: storagePath,
        signedUrl: signedUrl,
        expiresAt: DateTime.now().add(expiresIn),
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('Error creating export: $e');
      rethrow;
    }
  }

  /// List exports for a shop
  Future<List<dynamic>> listExports(String shopId) async {
    try {
      final files = await SupabaseService.storage
          .from('exports')
          .list(path: '$shopId/exports');

      return files;
    } catch (e) {
      debugPrint('Error listing exports: $e');
      rethrow;
    }
  }

  /// Delete export
  Future<void> deleteExport(String storagePath) async {
    try {
      await SupabaseService.storage.from('exports').remove([storagePath]);

      debugPrint('Deleted export: $storagePath');
    } catch (e) {
      debugPrint('Error deleting export: $e');
      rethrow;
    }
  }

  // ================================================
  // HELPERS
  // ================================================

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get file size in human-readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Export result class
class ExportResult {
  final String storagePath;
  final String signedUrl;
  final DateTime expiresAt;
  final String fileName;

  ExportResult({
    required this.storagePath,
    required this.signedUrl,
    required this.expiresAt,
    required this.fileName,
  });
}
