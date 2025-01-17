import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_model.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/components/tree.dart';

enum OutputType { user, model }

class HomeModel extends BaseModel {
  A.BackendInfo? backendInfo;
  Map<String, A.ModelInfo>? models;
  String? model;

  String? input;
  String? searchPrefix;
  Node<dynamic> tree =
      Node.root(data: {"type": "root", "value": "Search tree"});

  int outputIndex = 0;
  List<dynamic> outputs = [];

  Queue<Message> messages = Queue();

  late TextEditingController inputController;

  bool get validModel =>
      model != null && models != null && models!.containsKey(model);

  bool _ready = false;

  bool get ready => _ready;

  bool get available => models?.isNotEmpty ?? false;

  bool _waiting = false;

  bool get waiting => _waiting;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _generation;

  bool get generating => _waiting || _generation != null;

  bool get hasInput => inputController.text.isNotEmpty;

  bool sampling = false;

  int beamWidth = 5;

  Future<void> init(
    TextEditingController inputController,
  ) async {
    this.inputController = inputController;

    final modelRes = await A.api.models();
    models = modelRes.value;

    final infoRes = await A.api.info();
    backendInfo = infoRes.value;

    final prefs = await SharedPreferences.getInstance();
    model = prefs.getString("model");
    sampling = prefs.getBool("sampling") ?? true;
    beamWidth = prefs.getInt("beamWidth") ?? 5;
    if (!validModel) {
      model = models?.keys.firstOrNull;
    }

    _ready = true;
    notifyListeners();
  }

  saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (model != null) {
      await prefs.setString("model", model!);
    } else {
      await prefs.remove("model");
    }
    await prefs.setBool("sampling", sampling);
    await prefs.setInt("beamWidth", beamWidth);
  }

  bool isValidPreset(Preset preset) {
    return models?.containsKey(preset.model) ?? false;
  }

  Future<void> run(String inputString) async {
    _waiting = true;
    input = inputString;
    searchPrefix = null;
    tree.clear();
    outputIndex = 0;
    inputController.clear();
    outputs.clear();
    notifyListeners();

    _channel = await A.api.connect();
    if (_channel == null) {
      messages.add(Message("Failed to connect to backend", Status.error));
    } else {
      final data = jsonEncode({
        "model": model!,
        "input": {
          "question": inputString,
        },
        "inference_options": {
          "beam_width": beamWidth,
          "sample": sampling,
        }
      });
      _channel!.sink.add(data);
      _generation = _channel!.stream.listen(
        (data) async {
          try {
            final json = jsonDecode(data);
            if (json.containsKey("error")) {
              messages.add(Message(json["error"], Status.error));
              await stop();
              return;
            }
            final type = json["type"] as String;
            switch (type) {
              case "output":
                outputs = json["output"];
                break;
              case "prefix":
                searchPrefix = json["prefix"] as String;
                break;
              case "sparql" || "search" || "select":
                final node = tree.find(json["path"].cast<String>());
                if (node != null) {
                  for (final item in json[type]) {
                    final child = Node(
                      item["key"] as String,
                      {
                        "type": type,
                        "score": item["score"],
                        "value": item["value"]
                      },
                    );
                    node.add(child);
                  }
                }
                break;
              default:
                break;
            }
            // signal success back to server
            _channel!.sink.add(jsonEncode({"status": "ok"}));
            notifyListeners();
          } catch (e) {
            debugPrint("Got error: $e");
            await stop();
            return;
          }
        },
        onError: (e) async {
          debugPrint("Error in Websocket stream: $e");
          await stop();
        },
        onDone: () async {
          await stop();
        },
        cancelOnError: true,
      );
    }
    _waiting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _channel?.sink.close();
    await _generation?.cancel();
    _generation = null;
    _channel = null;
    notifyListeners();
  }
}
