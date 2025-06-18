import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileService {
  // XMLファイルを保存してシェア
  static Future<void> saveAndShareXml(String xmlContent, String fileName) async {
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

  // アプリのドキュメントディレクトリからXMLファイルを読み込み
  static Future<List<File>> getXmlFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((file) => file.path.endsWith('.xml'))
          .cast<File>()
          .toList();
      
      // 作成日時でソート（新しい順）
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      return files;
    } catch (e) {
      return [];
    }
  }

  // ファイルの内容を読み込み
  static Future<String> readFileContent(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  // ファイルを削除
  static Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}