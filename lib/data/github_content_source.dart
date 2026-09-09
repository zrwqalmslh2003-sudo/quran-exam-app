import 'dart:convert';
import 'dart:io';

import 'content_manifest.dart';

class ContentFetchException implements Exception {
  ContentFetchException(this.message, {this.statusCode, this.url});

  final String message;
  final int? statusCode;
  final String? url;

  @override
  String toString() => 'ContentFetchException: $message';
}

class GithubContentSource {
  GithubContentSource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.baseUrl,
  });

  final String owner;
  final String repo;
  final String branch;
  final String? baseUrl;

  static const _defaultBase = 'https://raw.githubusercontent.com';
  static const _timeout = Duration(seconds: 15);

  Uri urlFor(String path, {String? branch}) {
    final base = baseUrl ?? _defaultBase;
    return Uri.parse('$base/$owner/$repo/${branch ?? this.branch}/$path');
  }

  Future<List<int>> fetchBytes(
    Uri url, {
    int maxBytes = 8 * 1024 * 1024,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw ContentFetchException('حجم الاستجابة يتجاوز الحد المسموح');
        }
      }
      if (response.statusCode != HttpStatus.ok) {
        throw ContentFetchException(
          'فشل جلب المحتوى (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
          url: url.toString(),
        );
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> fetchText(Uri url, {int maxBytes = 8 * 1024 * 1024}) async =>
      utf8.decode(await fetchBytes(url, maxBytes: maxBytes));

  Future<ContentManifest> fetchManifest() async {
    final raw = await fetchText(urlFor('manifest.json'), maxBytes: 512 * 1024);
    return ContentManifest.fromJson(jsonDecode(raw));
  }
}
