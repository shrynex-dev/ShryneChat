enum MarkdownListKind { ordered, unordered, task }

sealed class MarkdownNode {
  const MarkdownNode();
}

class MarkdownDocument {
  const MarkdownDocument(this.blocks);

  final List<BlockNode> blocks;
}

sealed class BlockNode extends MarkdownNode {
  const BlockNode();
}

class ParagraphNode extends BlockNode {
  const ParagraphNode(this.inlines);

  final List<InlineNode> inlines;
}

class HeadingNode extends BlockNode {
  const HeadingNode({required this.level, required this.inlines});

  final int level;
  final List<InlineNode> inlines;
}

class BlockquoteNode extends BlockNode {
  const BlockquoteNode(this.blocks);

  final List<BlockNode> blocks;
}

class HorizontalRuleNode extends BlockNode {
  const HorizontalRuleNode();
}

class CodeBlockNode extends BlockNode {
  const CodeBlockNode({required this.language, required this.code});

  final String? language;
  final String code;
}

class ListNode extends BlockNode {
  const ListNode({required this.kind, required this.items});

  final MarkdownListKind kind;
  final List<ListItemNode> items;
}

class ListItemNode extends MarkdownNode {
  const ListItemNode({
    required this.inlines,
    this.checked,
    this.children = const [],
  });

  final List<InlineNode> inlines;
  final bool? checked;
  final List<ListNode> children;
}

class TableNode extends BlockNode {
  const TableNode({
    required this.headers,
    required this.alignments,
    required this.rows,
  });

  final List<List<InlineNode>> headers;
  final List<TableAlignment> alignments;
  final List<List<List<InlineNode>>> rows;
}

enum TableAlignment { left, center, right }

sealed class InlineNode extends MarkdownNode {
  const InlineNode();
}

class TextNode extends InlineNode {
  const TextNode(this.text);

  final String text;
}

class EmphasisNode extends InlineNode {
  const EmphasisNode(this.children);

  final List<InlineNode> children;
}

class StrongNode extends InlineNode {
  const StrongNode(this.children);

  final List<InlineNode> children;
}

class StrongEmphasisNode extends InlineNode {
  const StrongEmphasisNode(this.children);

  final List<InlineNode> children;
}

class StrikethroughNode extends InlineNode {
  const StrikethroughNode(this.children);

  final List<InlineNode> children;
}

class InlineCodeNode extends InlineNode {
  const InlineCodeNode(this.code);

  final String code;
}

class LinkNode extends InlineNode {
  const LinkNode({required this.label, required this.url});

  final List<InlineNode> label;
  final String url;
}

class LineBreakNode extends InlineNode {
  const LineBreakNode();
}
