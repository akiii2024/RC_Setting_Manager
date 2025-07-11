import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileService {
  // XMLファイルを保存してシェア
  static Future<void> saveAndShareXml(
      String xmlContent, String fileName) async {
    if (kIsWeb) {
      // Web環境では直接ダウンロード
      await _downloadFileWeb(xmlContent, fileName);
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(xmlContent);

      // ファイルを共有
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'RC Car Settings Export',
      );
    } catch (e) {
      throw Exception('Failed to save and share file: $e');
    }
  }

  // Web環境でのファイルダウンロード
  static Future<void> _downloadFileWeb(String content, String fileName) async {
    if (kIsWeb) {
      // Web環境では、share_plus を使用してファイルを共有
      // または、ダウンロード機能を実装
      await Share.share(content, subject: fileName);
    }
  }

  // アプリのドキュメントディレクトリからXMLファイルを読み込み
  static Future<List<dynamic>> getXmlFiles() async {
    if (kIsWeb) {
      // Web環境では空のリストを返す（ローカルファイルアクセス不可）
      return [];
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .where((file) => file.path.endsWith('.xml'))
          .cast<File>()
          .toList();

      // 作成日時でソート（新しい順）
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files;
    } catch (e) {
      return [];
    }
  }

  // ファイルの内容を読み込み
  static Future<String> readFileContent(dynamic file) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではローカルファイルの読み込みはできません');
    }

    try {
      return await (file as File).readAsString();
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  // ファイルを削除
  static Future<void> deleteFile(dynamic file) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではファイル削除はできません');
    }

    try {
      if (await (file as File).exists()) {
        await (file as File).delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
