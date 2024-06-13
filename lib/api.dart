import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import 'package:webapp/components/message.dart';
import 'package:webapp/config.dart';
import 'package:webapp/home_model.dart';
import 'package:window_location_href/window_location_href.dart' as whref;

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
  String output;
  OutputType outputType;
  Runtime runtime;

  ModelOutput(
    this.output,
    this.outputType,
    this.runtime,
  );
}

class Api {
  late final String _baseURL;
  late final String _wsBaseURL;
  late final String _webBaseURL;

  String get webBaseURL => _webBaseURL;

  Api._privateConstructor() {
    String? href = whref.href;
    if (href != null) {
      if (href.endsWith("/")) {
        href = href.substring(0, href.length - 1);
      }
      String rel = baseURL;
      if (rel.startsWith("/")) {
        rel = rel.substring(1);
      }
      if (kReleaseMode) {
        // for release mode use href
        _baseURL = "$href/$rel";
        final uri = Uri.parse(_baseURL);
        _wsBaseURL = "wss://${uri.host}:${uri.port}/$rel";
      } else {
        // for local development use localhost
        _baseURL = "http://localhost:40000/$rel";
        _wsBaseURL = "ws://localhost:40000/$rel";
      }
      _webBaseURL = href;
    } else {
      throw UnsupportedError("unknown platform");
    }
  }

  static final Api _instance = Api._privateConstructor();

  static Api get instance {
    return _instance;
  }

  Future<ApiResult<List<ModelInfo>>> models() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/models"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting models: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      List<ModelInfo> modelInfos = [];
      for (final modelInfo in json["models"]) {
        modelInfos.add(
          ModelInfo(
            modelInfo["name"],
            modelInfo["description"],
            modelInfo["tags"].cast<String>(),
          ),
        );
      }
      return ApiResult(res.statusCode, value: modelInfos);
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<ApiResult<BackendInfo>> info() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/info"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting backend info: ${res.body}",
        );
      }
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
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<WebSocketChannel?> generate(
    String text,
    String? info,
    String model,
    int beamWidth,
    bool sampling,
  ) async {
    var data = {
      "model": model,
      "text": text,
      "info": info,
      "sampling_strategy": sampling ? "top_p" : "greedy",
      "beam_width": beamWidth,
      "top_k": 100,
      "top_p": 0.90
    };
    try {
      final channel = WebSocketChannel.connect(Uri.parse("$_wsBaseURL/live"));
      await channel.ready;
      channel.sink.add(jsonEncode(data));
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
