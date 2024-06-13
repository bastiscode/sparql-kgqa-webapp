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

enum OutputType { user, prompt, model, sparql }

class HomeModel extends BaseModel {
  A.BackendInfo? backendInfo;
  List<A.ModelInfo> modelInfos = [];
  String? model;

  String? input;
  String? prompt;
  String? output;
  String? sparql;
  List<A.ModelOutput> outputs = [];

  Queue<Message> messages = Queue();

  late TextEditingController inputController;
  late TextEditingController guidanceController;

  bool get validModel =>
      model != null &&
      modelInfos.indexWhere((info) => info.name == model!) != -1;

  bool _ready = false;

  bool get ready => _ready;

  bool get available => modelInfos.isNotEmpty;

  bool _waiting = false;

  bool get waiting => _waiting;

  WebSocketChannel? _channel;
  StreamSubscription? _generation;

  bool get generating => _waiting || _generation != null;

  bool get hasResults => outputs.isNotEmpty;

  bool get hasInput => inputController.text.isNotEmpty;

  bool sampling = false;

  int beamWidth = 10;

  Future<void> init(
    TextEditingController inputController,
    TextEditingController guidanceController,
  ) async {
    this.inputController = inputController;
    this.guidanceController = guidanceController;

    final modelRes = await A.api.models();
    if (modelRes.value != null) {
      modelInfos = modelRes.value!;
    }

    final infoRes = await A.api.info();
    if (infoRes.value != null) {
      backendInfo = infoRes.value!;
    }

    final prefs = await SharedPreferences.getInstance();
    model = prefs.getString("model");
    sampling = prefs.getBool("sampling") ?? true;
    beamWidth = prefs.getInt("beamWidth") ?? 1;
    if (!validModel) {
      model = modelInfos.firstOrNull?.name;
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
    return modelInfos.indexWhere((info) => info.name == preset.model) != -1;
  }

  Future<void> run(String inputString) async {
    final time = Stopwatch()..start();
    _waiting = true;
    input = inputString;
    prompt = null;
    sparql = null;
    output = null;
    inputController.clear();
    outputs.clear();
    notifyListeners();

    _channel = await A.api.generate(
      inputString,
      guidanceController.text,
      model!,
      beamWidth,
      sampling,
    );
    if (_channel == null) {
      messages.add(Message("failed to get response", Status.error));
    } else {
      _generation = _channel!.stream.listen(
        (data) async {
          try {
            final json = jsonDecode(data);
            if (json.containsKey("error")) {
              messages.add(Message(json["error"], Status.error));
              notifyListeners();
              return;
            }
            final out = A.ModelOutput(
              json["output"],
              outputs.isEmpty ? OutputType.prompt : OutputType.model,
              A.Runtime.fromJson(
                json["runtime"],
                time.elapsed.inMilliseconds / 1000,
              ),
            );
            outputs.add(out);
            prompt ??= out.output;
            output = out.output;
            notifyListeners();
          } catch (e) {
            return;
          }
        },
        onError: (_) async {
          await stop();
        },
        onDone: () async {
          output = outputs.elementAtOrNull(outputs.length - 2)?.output;
          sparql = outputs.lastOrNull?.output;
          await stop();
        },
        cancelOnError: true,
      );
    }
    _waiting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _generation?.cancel();
    await _channel?.sink.close();
    _generation = null;
    _channel = null;
    notifyListeners();
  }
}
