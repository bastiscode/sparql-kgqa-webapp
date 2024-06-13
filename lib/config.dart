import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/presets.dart';

// some general configuration options
const String title = "SPARQL KGQA";
const String description =
    "Answer questions over knowledge graphs with large language models";
const String lastUpdated = "June 13, 2024";

const String baseURL = "/api";
const bool enableGuidance = false;

// display links to additional resources on the website,
// will be shown as action chips below the title bar
const List<Link> links = [
  Link(
    "Code",
    "https://github.com/bastiscode/sparql-kgqa",
    icon: FontAwesomeIcons.github,
  ),
  Link(
    "Wikidata indices",
    "https://github.com/bastiscode/wikidata-natural-language-index",
    icon: FontAwesomeIcons.github,
  ),
  Link(
    "Webapp",
    "https://github.com/bastiscode/sparql-kgqa-webapp",
    icon: FontAwesomeIcons.github,
  ),
];

// examples
const Map<String, List<String>> examples = {
  "Wikidata Simple": [
    "What jobs did Angela Merkel have?",
    "Who was Britney Spears married to?",
    "Name the siblings of the the god Jupiter",
    "How heavy is the Earth?"
  ],
};

// display clickable choice chips inside pipeline selection
// that set a specific model for each task on click,
// default preset is always assumed to be the first in
// the following list
const List<Preset> presets = [];
