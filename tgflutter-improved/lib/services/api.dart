import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiUrl;
  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 20);

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> saveToken(String t) => _storage.write(key: 'token', value: t);
  static Future<void> deleteToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers()).timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final r = await http.post(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth), body: jsonEncode(body)).timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final r = await http.patch(Uri.parse('$baseUrl$path'), headers: await _headers(), body: jsonEncode(body)).timeout(_timeout);
    return _handle(r);
  }

  static Future<dynamic> delete(String path) async {
    final r = await http.delete(Uri.parse('$baseUrl$path'), headers: await _headers()).timeout(_timeout);
    return _handle(r);
  }

  static dynamic _handle(http.Response r) {
    final body = utf8.decode(r.bodyBytes);
    dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw ApiException('Ошибка сервера (${r.statusCode})', r.statusCode);
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    throw ApiException(data['error'] ?? 'Ошибка сервера', r.statusCode);
  }

  // --- Auth ---
  static Future<void> sendOtp(String email) =>
      post('/api/auth/send-otp', {'email': email}, auth: false);

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final data = await post('/api/auth/verify-otp', {'email': email, 'code': code}, auth: false);
    // If existing user, server returns token directly
    if (data['token'] != null) await saveToken(data['token']);
    return data as Map<String, dynamic>;
  }

  static Future<String> login(String email, String code) async {
    final data = await post('/api/auth/login', {'email': email, 'code': code}, auth: false);
    if (data['token'] != null) await saveToken(data['token']);
    return data['token'] as String;
  }

  static Future<String> register(String email, String username, String displayName) async {
    final data = await post('/api/auth/register', {
      'email': email,
      'username': username,
      'displayName': displayName,
    }, auth: false);
    await saveToken(data['token']);
    return data['token'] as String;
  }

  static Future<Map<String, dynamic>> getMe() async {
    return (await get('/api/auth/me')) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? statusText,
  }) async {
    return (await patch('/api/auth/me', {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (statusText != null) 'statusText': statusText,
    })) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> searchUsersGlobal(String q) async {
    return (await get('/api/auth/users/search?q=${Uri.encodeComponent(q)}')) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return (await get('/api/auth/users/$userId')) as Map<String, dynamic>;
  }

  // --- Chats ---
  static Future<List<dynamic>> getChats() async => (await get('/api/chats')) as List<dynamic>;

  static Future<Map<String, dynamic>> getChatInfo(String chatId) async =>
      (await get('/api/chats/$chatId')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> openDirectChat(String targetUserId) async =>
      (await post('/api/chats/direct', {'targetUserId': targetUserId})) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> createGroup(String name, List<String> memberIds, {String? description}) async =>
      (await post('/api/chats/group', {'name': name, 'memberIds': memberIds, 'description': description})) as Map<String, dynamic>;

  static Future<List<dynamic>> getMessages(String chatId, {String? before}) async {
    final q = before != null ? '?before=${Uri.encodeComponent(before)}' : '';
    return (await get('/api/chats/$chatId/messages$q')) as List<dynamic>;
  }

  static Future<List<dynamic>> searchMessages(String chatId, String q) async =>
      (await get('/api/chats/$chatId/search?q=${Uri.encodeComponent(q)}')) as List<dynamic>;

  static Future<List<dynamic>> getChatMembers(String chatId) async =>
      (await get('/api/chats/$chatId/members')) as List<dynamic>;

  static Future<List<dynamic>> searchUsers(String q) async =>
      (await get('/api/chats/users/search?q=${Uri.encodeComponent(q)}')) as List<dynamic>;

  static Future<Map<String, dynamic>> pinMessage(String chatId, String messageId) async =>
      (await post('/api/chats/$chatId/messages/$messageId/pin', {})) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> reactToMessage(String chatId, String messageId, String emoji) async =>
      (await post('/api/chats/$chatId/messages/$messageId/react', {'emoji': emoji})) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> toggleMuteChat(String chatId) async =>
      (await post('/api/chats/$chatId/mute', {})) as Map<String, dynamic>;

  static Future<void> addMember(String chatId, String userId) =>
      post('/api/chats/$chatId/members', {'userId': userId});

  static Future<void> removeMember(String chatId, String userId) =>
      delete('/api/chats/$chatId/members/$userId');

  // --- Contacts ---
  static Future<List<dynamic>> getContacts() async => (await get('/api/contacts')) as List<dynamic>;

  static Future<Map<String, dynamic>> addContact(String contactId, {String? nickname}) async =>
      (await post('/api/contacts', {'contactId': contactId, 'nickname': nickname})) as Map<String, dynamic>;

  static Future<void> removeContact(String contactId) => delete('/api/contacts/$contactId');

  static Future<bool> isContact(String userId) async {
    final data = await get('/api/contacts/check/$userId');
    return data['isContact'] as bool;
  }

  // --- Channels ---
  static Future<List<dynamic>> exploreChannels({String? q}) async {
    final qs = q != null ? '?q=${Uri.encodeComponent(q)}' : '';
    return (await get('/api/channels/explore$qs')) as List<dynamic>;
  }

  static Future<List<dynamic>> myChannels() async => (await get('/api/channels/my')) as List<dynamic>;

  static Future<Map<String, dynamic>> getChannel(String username) async =>
      (await get('/api/channels/$username')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> subscribeChannel(String channelId) async =>
      (await post('/api/channels/$channelId/subscribe', {})) as Map<String, dynamic>;

  static Future<List<dynamic>> getChannelPosts(String channelId, {String? before}) async {
    final q = before != null ? '?before=${Uri.encodeComponent(before)}' : '';
    return (await get('/api/channels/$channelId/posts$q')) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createChannel(String username, String name, {String? description, bool isPublic = true}) async =>
      (await post('/api/channels', {'username': username, 'name': name, 'description': description, 'isPublic': isPublic})) as Map<String, dynamic>;

  static Future<void> createPost(String channelId, String content, {bool isPaid = false, List<String> mediaUrls = const []}) =>
      post('/api/channels/$channelId/posts', {'content': content, 'isPaid': isPaid, 'mediaUrls': mediaUrls});

  static Future<void> deletePost(String channelId, String postId) =>
      delete('/api/channels/$channelId/posts/$postId');

  // --- AI ---
  static Future<String> askAi(String chatId, String message) async {
    final data = await post('/api/ai/chat/$chatId', {'message': message, 'includeHistory': true});
    return data['response'] as String;
  }

  static Future<String> summarizeChat(String chatId) async {
    final data = await get('/api/ai/summarize/$chatId');
    return data['summary'] as String;
  }

  static Future<String> translateText(String text, String targetLang) async {
    final data = await post('/api/ai/translate', {'text': text, 'targetLang': targetLang});
    return data['result'] as String;
  }

  static Future<String> askAiFree(String message) async {
    final data = await post('/api/ai/ask', {'message': message});
    return data['response'] as String;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
