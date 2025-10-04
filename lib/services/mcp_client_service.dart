import 'package:dio/dio.dart';

/// Base class for MCP (Model Context Protocol) client
/// This service handles communication with MCP-compatible servers
class MCPClientService {
  final String serverUrl;
  final Dio _dio;

  MCPClientService({required this.serverUrl, Map<String, String>? headers}) : _dio = Dio(BaseOptions(baseUrl: serverUrl, headers: headers ?? {'Content-Type': 'application/json'}, connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)));

  /// Call an MCP tool on the server
  Future<Map<String, dynamic>> callTool({required String toolName, required Map<String, dynamic> arguments}) async {
    try {
      final response = await _dio.post('/tools/call', data: {'name': toolName, 'arguments': arguments});

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('MCP tool call failed: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      throw Exception('Error calling MCP tool: $e');
    }
  }

  /// List available tools from the MCP server
  Future<List<Map<String, dynamic>>> listTools() async {
    try {
      final response = await _dio.get('/tools/list');
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['tools'] ?? []);
    } on DioException catch (e) {
      throw Exception('Failed to list MCP tools: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      throw Exception('Error listing MCP tools: $e');
    }
  }

  /// Get information about a specific resource
  Future<Map<String, dynamic>> readResource(String resourceUri) async {
    try {
      final response = await _dio.post('/resources/read', data: {'uri': resourceUri});

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Failed to read resource: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      throw Exception('Error reading resource: $e');
    }
  }
}
