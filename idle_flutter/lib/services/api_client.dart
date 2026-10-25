import 'dart:convert';
import 'package:http/http.dart' as http;

abstract interface class AuthTokenProvider { Future<String> idToken(); }
class ApiRequest { const ApiRequest(this.path,this.method,this.headers,this.body); final String path,method; final Map<String,String> headers; final String? body; }
class ApiResponse { const ApiResponse(this.statusCode,this.body); final int statusCode; final String body; }
abstract interface class ApiTransport { Future<ApiResponse> send(ApiRequest request); }
class HttpApiTransport implements ApiTransport {
  HttpApiTransport({http.Client? client}):client=client??http.Client(); final http.Client client;
  @override Future<ApiResponse> send(ApiRequest r) async { final request=http.Request(r.method,Uri.parse(r.path));request.headers.addAll(r.headers);if(r.body!=null)request.body=r.body!;final streamed=await client.send(request);return ApiResponse(streamed.statusCode,await streamed.stream.bytesToString()); }
}
class SaveConflict implements Exception { const SaveConflict(this.revision); final int revision; }
class ApiFailure implements Exception { const ApiFailure(this.statusCode,this.message); final int statusCode; final String message; }
class ApiClient {
  ApiClient(this.auth,this.transport); final AuthTokenProvider auth; final ApiTransport transport;
  Future<Map<String,dynamic>> _request(String path,String method,[Object? payload]) async { final token=await auth.idToken(); final body=payload==null?null:jsonEncode(payload);final response=await transport.send(ApiRequest(path,method,{'authorization':'Bearer $token',if(body!=null)'content-type':'application/json'},body));Map<String,dynamic> data={};try{final d=jsonDecode(response.body);if(d is Map<String,dynamic>)data=d;}catch(_){}
    if(response.statusCode==409)throw SaveConflict(data['revision'] is int?data['revision'] as int:0);if(response.statusCode<200||response.statusCode>=300)throw ApiFailure(response.statusCode,data['error']?.toString()??'Cloud request failed (${response.statusCode}).');return data; }
  Future<Map<String,dynamic>> get(String path)=>_request(path,'GET');
  Future<Map<String,dynamic>> getPublic(String path) async { final response=await transport.send(ApiRequest(path,'GET',const{},null));Map<String,dynamic> data={};try{final d=jsonDecode(response.body);if(d is Map<String,dynamic>)data=d;}catch(_){}if(response.statusCode<200||response.statusCode>=300)throw ApiFailure(response.statusCode,data['error']?.toString()??'Cloud request failed (${response.statusCode}).');return data; }
  Future<Map<String,dynamic>> post(String path,[Object? body])=>_request(path,'POST',body);
  Future<Map<String,dynamic>> putSave(Map<String,Object?> save,int revision)=>_request('/api/save','PUT',{'save':save,'revision':revision});
}
