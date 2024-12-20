import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import 'package:webapp/components/message.dart';
import 'package:webapp/config.dart';
import 'package:window_location_href/window_location_href.dart' as whref;

class SocketStream {
  final _socketResponse = StreamController<String>();

  void add(String data) => _socketResponse.sink.add(data);

  Stream<String> get stream => _socketResponse.stream;

  void dispose() {
    _socketResponse.close();
  }
}

class ApiResult<T> {
  int statusCode;
  String? message;
  T? value;

  ApiResult(this.statusCode, {this.message, this.value}) {
    assert(this.message != null || this.value != null);
    assert(!(this.message == null && this.value == null));
  }
}

class ModelInfo {
  String name;
  String description;
  List<String> tags;

  ModelInfo(this.name, this.description, this.tags);
}

class BackendInfo {
  List<String> gpuInfos;
  String cpuInfo;
  double timeout;

  BackendInfo(this.gpuInfos, this.cpuInfo, this.timeout);
}

class Runtime {
  int b;
  double backendS;
  double clientS;

  Runtime(this.b, this.backendS, this.clientS);

  static Runtime fromJson(
    dynamic json,
    double clientS,
  ) {
    return Runtime(
      json["b"],
      json["s"],
      clientS,
    );
  }
}

class ModelOutput {
  List<String> output;
  Runtime runtime;

  ModelOutput(
    this.output,
    this.runtime,
  );
}

class Api {
  late final String _apiURL;
  late final String _websocketURL;

  late final String _webBaseURL;

  String get webBaseURL => _webBaseURL;

  Api._privateConstructor() {
    String? href = whref.href;
    if (href == null) {
      throw UnsupportedError("Unknown platform");
    }
    if (href.endsWith("/")) {
      href = href.substring(0, href.length - 1);
    }
    if (kReleaseMode) {
      // for release mode use href
      _apiURL = "$href$apiURL";
      final uri = Uri.parse(href);
      _websocketURL = "wss://${uri.host}:${uri.port}$apiURL/live";
    } else {
      // for local development use localhost
      _apiURL = "http://localhost:40000";
      _websocketURL = "ws://localhost:40000/live";
    }
    _webBaseURL = href;
  }

  static final Api _instance = Api._privateConstructor();

  static Api get instance {
    return _instance;
  }

  Future<ApiResult<Map<String, ModelInfo>>> models() async {
    try {
      final res = await http.get(Uri.parse("$_apiURL/models"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "Error getting models: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      Map<String, ModelInfo> modelInfos = {};
      for (final entry in json["models"].entries) {
        modelInfos[entry.key] = ModelInfo(
          entry.value["name"],
          entry.value["description"],
          entry.value["tags"].cast<String>(),
        );
      }
      return ApiResult(res.statusCode, value: modelInfos);
    } catch (e) {
      debugPrint("Error loading models: $e");
      return ApiResult(500, message: "Internal error: $e");
    }
  }

  Future<ApiResult<BackendInfo>> info() async {
    try {
      final res = await http.get(Uri.parse("$_apiURL/info"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "Error getting backend info: ${res.body}",
        );
      }
      debugPrint("Info: ${res.body}");
      final json = jsonDecode(res.body);
      return ApiResult(
        res.statusCode,
        value: BackendInfo(
          json["gpu"].cast<String>(),
          json["cpu"],
          json["timeout"] as double,
        ),
      );
    } catch (e) {
      return ApiResult(500, message: "Internal error: $e");
    }
  }

  Future<WebSocketChannel?> connect() async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_websocketURL));
      await channel.ready;
      return channel;
    } catch (e) {
      return null;
    }
  }
}

final api = Api.instance;

Message errorMessageFromApiResult(ApiResult result) {
  return Message("${result.statusCode}: ${result.message}", Status.error);
}
