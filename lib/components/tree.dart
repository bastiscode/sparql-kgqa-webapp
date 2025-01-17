import 'package:flutter/material.dart';

class Node<T> {
  final String key;
  final T? data;
  final List<Node<T>> children = [];

  Node(this.key, this.data);

  void add(Node<T> child) {
    children.add(child);
  }

  void clear() {
    children.clear();
  }

  Node<T>? find(List<String> path) {
    var node = this;
    for (final key in path) {
      final idx = node.children.indexWhere((child) => child.key == key);
      if (idx < 0) return null;
      node = node.children[idx];
    }
    return node;
  }

  static Node<T> root<T>({String? key, dynamic data}) {
    return Node(key ?? "", data);
  }
}

typedef NodeBuilder<T> = Widget Function(BuildContext context, Node<T> node);
typedef OptionalNodeBuilder<T> = Widget? Function(
    BuildContext context, Node<T> node);

class NodeView<T> extends StatefulWidget {
  final Node<T> node;
  final NodeBuilder titleBuilder;
  final OptionalNodeBuilder? subtitleBuilder;

  const NodeView({
    required this.node,
    required this.titleBuilder,
    this.subtitleBuilder,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _NodeViewState();
}

class _NodeViewState extends State<NodeView> {
  @override
  Widget build(BuildContext context) {
    if (widget.node.children.isEmpty) {
      return ListTile(
        title: widget.titleBuilder(context, widget.node),
        subtitle: widget.subtitleBuilder != null
            ? widget.subtitleBuilder!(context, widget.node)
            : null,
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: const Border(),
      );
    }
    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      visualDensity: VisualDensity.compact,
      dense: true,
      maintainState: true,
      shape: const Border(),
      title: widget.titleBuilder(context, widget.node),
      subtitle: widget.subtitleBuilder != null
          ? widget.subtitleBuilder!(context, widget.node)
          : null,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
      children: widget.node.children
          .map((child) => NodeView(
                node: child,
                titleBuilder: widget.titleBuilder,
                subtitleBuilder: widget.subtitleBuilder,
              ))
          .toList(),
    );
  }
}
