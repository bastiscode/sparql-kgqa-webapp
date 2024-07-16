import 'dart:math';

import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_view.dart';
import 'package:webapp/colors.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/config.dart';
import 'package:webapp/home_model.dart';
import 'package:webapp/utils.dart';

Widget wrapScaffold(Widget widget) {
  return SafeArea(child: Scaffold(body: widget));
}

Widget wrapPadding(Widget widget) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: widget,
  );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    inputController.addListener(() {
      setState(() {});
    });
    inputFocus.requestFocus();
  }

  @override
  void dispose() {
    inputController.dispose();
    scrollController.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  Future<void> Function() launchOrMessage(String address) {
    return () async {
      await launchUrl(Uri.parse(address));
    };
  }

  @override
  Widget build(BuildContext homeContext) {
    return BaseView<HomeModel>(
      onModelReady: (model) async {
        await model.init(
          inputController,
        );
      },
      builder: (context, model, child) {
        Future.delayed(
          Duration.zero,
          () {
            while (model.messages.isNotEmpty) {
              final message = model.messages.removeFirst();
              showMessage(context, message);
            }
          },
        );
        if (!model.ready) {
          return wrapScaffold(
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        }
        return SafeArea(
          child: Scaffold(
            body: wrapPadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  buildHeading(model),
                  const SizedBox(height: 8),
                  if (model.ready && !model.available) ...[
                    const Spacer(),
                    const Text(
                      "Could not find any models, "
                      "please check your backends and reload.",
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await model.init(
                          inputController,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reload"),
                    ),
                    const Spacer()
                  ] else ...[
                    Expanded(child: buildOutputs(model)),
                    const SizedBox(height: 8),
                    buildInput(model)
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildHeading(HomeModel model) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: links
                      .map((l) => LinkChip(l, launchOrMessage(l.url)))
                      .toList(),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: launchOrMessage(
                      "https://ad.informatik.uni-freiburg.de",
                    ),
                    child: SizedBox(
                      width: 160,
                      child: Image.network(
                        "${A.api.webBaseURL}"
                        "/assets/images/logo.png",
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              trailing: Wrap(
                runSpacing: 8,
                spacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.info_outlined,
                    ),
                    splashRadius: 16,
                    tooltip: "Show backend information",
                    onPressed: () {
                      if (model.backendInfo == null) {
                        showMessage(
                          context,
                          Message(
                            "backend info not available",
                            Status.warn,
                          ),
                        );
                        return;
                      }
                      showInfoDialog(
                        model.backendInfo!,
                      );
                    },
                  ),
                ],
              ),
              title: const Text(
                title,
                style: TextStyle(fontSize: 22),
              ),
              subtitle: const Text(
                description,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputTextField(HomeModel model) {
    final canRun = model.validModel &&
        !model.generating &&
        inputController.text.isNotEmpty;

    final buttons = [
      IconButton(
        onPressed: canRun
            ? () async {
                await model.run(model.inputController.text);
              }
            : null,
        icon: const Icon(Icons.start),
        color: uniBlue,
        tooltip: "Run model",
        splashRadius: 16,
      ),
      IconButton(
        onPressed: model.generating
            ? () async {
                await model.stop();
              }
            : null,
        icon: const Icon(Icons.stop_circle),
        color: uniBlue,
        tooltip: "Stop generation",
        splashRadius: 16,
      ),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
        ): () async {
          if (!canRun) return;
          await model.run(model.inputController.text);
        }
      },
      child: TextField(
        controller: model.inputController,
        readOnly: model.generating,
        minLines: 1,
        maxLines: 3,
        keyboardType: TextInputType.multiline,
        focusNode: inputFocus,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: "Enter your question",
          helperText: model.validModel
              ? model.hasResults
                  ? "${formatRuntime(model.outputs.last.runtime)} with ${model.model!}"
                  : "Running ${model.model!}"
              : "No model selected",
          helperMaxLines: 2,
          suffixIcon: model.inputController.text.contains("\n")
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: buttons,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: buttons,
                ),
        ),
      ),
    );
  }

  Widget buildInput(HomeModel model) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            inputTextField(model),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconButton(
                        splashRadius: 16,
                        onPressed: () {
                          showConfigurationSheet(model);
                        },
                        tooltip: "Show configuration",
                        icon: const Icon(Icons.settings),
                      ),
                      IconButton(
                        onPressed: !model.generating
                            ? () async {
                                model.input = null;
                                model.prompt = null;
                                model.output = null;
                                model.sparql = null;
                                model.outputIndex = 0;
                                model.outputs.clear();
                                model.notifyListeners();
                              }
                            : null,
                        icon: const Icon(Icons.clear),
                        color: !model.generating ? uniRed : null,
                        tooltip: "Clear",
                        splashRadius: 16,
                      ),
                      IconButton(
                        icon: Icon(
                          model.sampling
                              ? Icons.change_circle
                              : Icons.change_circle_outlined,
                        ),
                        tooltip:
                            "${!model.sampling ? "Disable" : "Enable"} determinism",
                        splashRadius: 16,
                        onPressed: () async {
                          model.sampling = !model.sampling;
                          await model.saveSettings();
                          model.notifyListeners();
                        },
                      ),
                      if (examples.isNotEmpty)
                        IconButton(
                          onPressed: !model.generating
                              ? () async {
                                  final example = await showExamplesDialog(
                                    examples,
                                  );
                                  if (example == null) {
                                    return;
                                  }
                                  inputController.value = TextEditingValue(
                                    text: example[1],
                                    composing: TextRange.collapsed(
                                      example.length,
                                    ),
                                  );
                                  inputFocus.requestFocus();
                                  model.notifyListeners();
                                }
                              : null,
                          icon: const Icon(Icons.list),
                          tooltip: "Choose an example",
                          splashRadius: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  showConfigurationSheet(HomeModel model) {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints.loose(
        const Size(double.infinity, double.infinity),
      ),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      isScrollControlled: true,
      isDismissible: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            String? infoText;
            if (model.validModel) {
              final info = model.modelInfos.firstWhere(
                (info) => info.name == model.model,
              );
              infoText = info.description;
              if (info.tags.isNotEmpty) {
                infoText += " (${info.tags.join(', ')})";
              }
            }
            final validPresets = presets
                .where(
                  (preset) => model.isValidPreset(preset),
                )
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  if (validPresets.isNotEmpty) ...[
                    Presets(
                      presets: validPresets,
                      model: model.model,
                      onSelected: (preset) {
                        if (preset == null) {
                          model.model = null;
                        } else {
                          model.model = preset.model;
                        }
                        setModalState(() {});
                        model.notifyListeners();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<String>(
                    value: model.model,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.text_snippet_outlined),
                      suffixIcon: IconButton(
                        splashRadius: 16,
                        tooltip: "Clear model",
                        color: uniRed,
                        icon: const Icon(Icons.clear),
                        onPressed: model.validModel
                            ? () async {
                                model.model = null;
                                await model.saveSettings();
                                setModalState(() {});
                                model.notifyListeners();
                              }
                            : null,
                      ),
                      hintText: "Select a model",
                      labelText: "SPARQL generation model",
                      helperMaxLines: 10,
                      helperText: infoText,
                    ),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    items: model.modelInfos.map<DropdownMenuItem<String>>(
                      (modelInfo) {
                        return DropdownMenuItem(
                          value: modelInfo.name,
                          child: Text(modelInfo.name),
                        );
                      },
                    ).toList(),
                    onChanged: (String? modelName) async {
                      model.model = modelName;
                      await model.saveSettings();
                      setModalState(() {});
                      model.notifyListeners();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData outputTypeToIcon(OutputType type) {
    switch (type) {
      case OutputType.user:
        return Icons.person;
      case OutputType.prompt:
        return Icons.text_snippet_outlined;
      case OutputType.model:
        return Icons.computer;
      case OutputType.sparql:
        return Icons.query_stats;
    }
  }

  Widget cyclingOutputCard(
    List<String> outputs,
    OutputType type,
    HomeModel model,
  ) {
    final valid = model.outputIndex < outputs.length;
    final text = valid ? outputs[model.outputIndex] : "";
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(outputTypeToIcon(type), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            margin: EdgeInsets.zero,
            child: wrapPadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [SelectableText(text.trim())],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (!model.generating && valid && outputs.length > 1) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: model.outputIndex > 0
                ? () {
                    model.outputIndex -= 1;
                    model.notifyListeners();
                  }
                : null,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
          Text("${model.outputIndex + 1} / ${outputs.length}"),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: model.outputIndex < outputs.length - 1
                ? () {
                    model.outputIndex += 1;
                    model.notifyListeners();
                  }
                : null,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
        ],
        ...outputButtons(text, type)
      ],
    );
  }

  List<Widget> outputButtons(String text, OutputType type) {
    return [
      if (type == OutputType.sparql) ...[
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final sparqlEnc = Uri.encodeQueryComponent(text);
            await launchOrMessage(
              "https://qlever.cs.uni-freiburg.de/"
              "wikidata/?query=$sparqlEnc",
            )();
          },
          tooltip: "Open in QLever",
          iconSize: 18,
          icon: const Icon(Icons.open_in_new),
        ),
        const SizedBox(width: 4),
      ],
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: text));
        },
        tooltip: "Copy to clipboard",
        iconSize: 18,
        icon: const Icon(Icons.copy),
      ),
    ];
  }

  Widget outputCard(String text, OutputType type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(outputTypeToIcon(type), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            margin: EdgeInsets.zero,
            child: wrapPadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [SelectableText(text.trim())],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        ...outputButtons(text, type)
      ],
    );
  }

  Widget buildOutputs(HomeModel model) {
    int count = 0;
    if (model.input != null) count += 1;
    if (model.prompt != null) count += 1;
    if (model.output != null) count += 1;
    if (model.sparql != null) count += 1;
    return ListView.separated(
      separatorBuilder: (_, __) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (_, index) {
        if (index == 0) {
          return outputCard(model.input!, OutputType.user);
        } else if (index == 1) {
          return outputCard(model.prompt!, OutputType.prompt);
        } else if (index == 2) {
          return cyclingOutputCard(
            model.output!,
            OutputType.model,
            model,
          );
        } else {
          return cyclingOutputCard(
            model.sparql!,
            OutputType.sparql,
            model,
          );
        }
      },
      itemCount: count,
    );
  }

  showInfoDialog(A.BackendInfo info) async {
    const optionPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 8);
    await showDialog(
      context: context,
      builder: (infoContext) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          clipBehavior: Clip.antiAlias,
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          title: const Text(
            "Info",
            textAlign: TextAlign.center,
          ),
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                elevation: 2,
                child: Column(
                  children: [
                    const SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Backend",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Timeout: ${info.timeout.toStringAsFixed(2)} seconds",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "CPU: ${info.cpuInfo}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ...info.gpuInfos.mapIndexed(
                      (idx, info) => SimpleDialogOption(
                        padding: optionPadding,
                        child: Text(
                          "GPU ${idx + 1}: $info",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget exampleGroup(
    String groupName,
    List<String> items,
    Function(List<String>) onSelected,
  ) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              visualDensity: VisualDensity.compact,
              title: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.separated(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, idx) {
                return ListTile(
                  visualDensity: VisualDensity.compact,
                  title: Text(items[idx]),
                  subtitle: Text(
                    "Example ${idx + 1}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => onSelected([groupName, items[idx]]),
                  // leading: const Icon(Icons.notes),
                );
              },
              separatorBuilder: (_, __) {
                return const Divider(height: 1);
              },
            )
          ],
        ),
      ),
    );
  }

  Future<List<String>?> showExamplesDialog(
    Map<String, List<String>> examples,
  ) async {
    return await showDialog<List<String>?>(
      context: context,
      builder: (dialogContext) {
        final exampleGroups = examples.entries
            .map((entry) {
              return exampleGroup(
                entry.key,
                entry.value,
                (item) => Navigator.of(dialogContext).pop(item),
              );
            })
            .toList()
            .cast<Widget>();
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: exampleGroups),
            ),
          ),
        );
      },
    );
  }
}
