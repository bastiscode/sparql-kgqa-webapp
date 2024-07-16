import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/api.dart';
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
  List<String>? output;
  List<String>? sparql;
  int outputIndex = 0;
  List<A.ModelOutput> outputs = [];

  Queue<Message> messages = Queue();

  late TextEditingController inputController;

  bool get validModel =>
      model != null &&
      modelInfos.indexWhere((info) => info.name == model!) != -1;

  bool _ready = false;

  bool get ready => _ready;

  bool get available => modelInfos.isNotEmpty;

  bool _waiting = false;

  bool get waiting => _waiting;

  SocketStream? _stream;
  Socket? _socket;
  StreamSubscription<String>? _generation;

  bool get generating => _waiting || _stream != null;

  bool get hasResults => outputs.isNotEmpty;

  bool get hasInput => inputController.text.isNotEmpty;

  bool sampling = false;

  int beamWidth = 5;

  Future<void> init(
    TextEditingController inputController,
  ) async {
    this.inputController = inputController;

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
    sampling = prefs.getBool("sampling") ?? false;
    beamWidth = prefs.getInt("beamWidth") ?? 5;
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
    output = null;
    sparql = null;
    outputIndex = 0;
    inputController.clear();
    outputs.clear();
    notifyListeners();

    final result = A.api.generate(
      inputString,
      model!,
      beamWidth,
      sampling,
    );
    if (result == null) {
      messages.add(Message("failed to connect to backend", Status.error));
    } else {
      final (stream, socket) = result;
      _stream = stream;
      _socket = socket;
      _generation = stream.stream.listen(
        (data) async {
          try {
            final json = jsonDecode(data);
            if (json.containsKey("error")) {
              messages.add(Message(json["error"], Status.error));
              await stop();
              return;
            }
            final generations =
                (json["output"] as List).map((item) => item as String).toList();
            final out = A.ModelOutput(
              generations,
              A.Runtime.fromJson(
                json["runtime"],
                time.elapsed.inMilliseconds / 1000,
              ),
            );
            outputs.add(out);
            if (prompt == null) {
              prompt = out.output.firstOrNull;
            } else {
              output = out.output;
            }
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
    _stream?.dispose();
    _socket?.dispose();
    _generation = null;
    _stream = null;
    _socket = null;
    notifyListeners();
  }
}
