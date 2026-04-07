import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ast.dart';

class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.document,
    required this.showLineNumbers,
  });

  final MarkdownDocument document;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in document.blocks)
          _BlockView(block: block, showLineNumbers: showLineNumbers),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.showLineNumbers});

  final BlockNode block;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (block) {
        ParagraphNode(:final inlines) => Text.rich(
          TextSpan(children: _inlineSpans(context, inlines)),
          style: theme.textTheme.bodyLarge,
        ),
        HeadingNode(:final level, :final inlines) => Text.rich(
          TextSpan(children: _inlineSpans(context, inlines)),
          style: _headingStyle(theme, level),
        ),
        HorizontalRuleNode() => Divider(
          height: 24,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        BlockquoteNode(:final blocks) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: MarkdownRenderer(
            document: MarkdownDocument(blocks),
            showLineNumbers: showLineNumbers,
          ),
        ),
        CodeBlockNode(:final language, :final code) => _CodeBlockCard(
          code: code,
          language: language,
          showLineNumbers: showLineNumbers,
        ),
        ListNode(:final items, :final kind) => _ListView(
          items: items,
          kind: kind,
          depth: 0,
        ),
        TableNode(:final headers, :final rows, :final alignments) => _TableView(
          headers: headers,
          rows: rows,
          alignments: alignments,
        ),
      },
    );
  }

  TextStyle _headingStyle(ThemeData theme, int level) {
    return switch (level) {
      1 => theme.textTheme.headlineMedium!,
      2 => theme.textTheme.headlineSmall!,
      3 => theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800),
      4 => theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
      5 => theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w800),
      _ => theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800),
    };
  }

  List<InlineSpan> _inlineSpans(BuildContext context, List<InlineNode> nodes) {
    final theme = Theme.of(context);

    return [
      for (final node in nodes)
        switch (node) {
          TextNode(:final text) => TextSpan(text: text),
          EmphasisNode(:final children) => TextSpan(
            children: _inlineSpans(context, children),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          StrongNode(:final children) => TextSpan(
            children: _inlineSpans(context, children),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          StrongEmphasisNode(:final children) => TextSpan(
            children: _inlineSpans(context, children),
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
          StrikethroughNode(:final children) => TextSpan(
            children: _inlineSpans(context, children),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          InlineCodeNode(:final code) => WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          LinkNode(:final label, :final url) => TextSpan(
            children: _inlineSpans(context, label),
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Link tapped: $url')));
              },
          ),
          LineBreakNode() => const TextSpan(text: '\n'),
        },
    ];
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.items,
    required this.kind,
    required this.depth,
  });

  final List<ListItemNode> items;
  final MarkdownListKind kind;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28 + (depth * 12),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _marker(index, items[index]),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: _inlineSpans(context, items[index].inlines),
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (items[index].children.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final child in items[index].children)
                          _ListView(
                            items: child.items,
                            kind: child.kind,
                            depth: depth + 1,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _marker(int index, ListItemNode item) {
    return switch (kind) {
      MarkdownListKind.ordered => '${index + 1}.',
      MarkdownListKind.task => item.checked == true ? '☑' : '☐',
      MarkdownListKind.unordered => '•',
    };
  }

  List<InlineSpan> _inlineSpans(BuildContext context, List<InlineNode> nodes) {
    return _BlockView(
      block: ParagraphNode(nodes),
      showLineNumbers: false,
    )._inlineSpans(context, nodes);
  }
}

class _TableView extends StatelessWidget {
  const _TableView({
    required this.headers,
    required this.rows,
    required this.alignments,
  });

  final List<List<InlineNode>> headers;
  final List<List<List<InlineNode>>> rows;
  final List<TableAlignment> alignments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            theme.colorScheme.surfaceContainerHighest,
          ),
          columns: [
            for (var index = 0; index < headers.length; index++)
              DataColumn(
                label: _CellRichText(
                  inlines: headers[index],
                  alignment: alignments[index],
                  isHeader: true,
                ),
              ),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  for (var index = 0; index < row.length; index++)
                    DataCell(
                      _CellRichText(
                        inlines: row[index],
                        alignment: alignments[index],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CellRichText extends StatelessWidget {
  const _CellRichText({
    required this.inlines,
    required this.alignment,
    this.isHeader = false,
  });

  final List<InlineNode> inlines;
  final TableAlignment alignment;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final spans = _BlockView(
      block: ParagraphNode(inlines),
      showLineNumbers: false,
    )._inlineSpans(context, inlines);

    return SizedBox(
      width: 140,
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: switch (alignment) {
          TableAlignment.left => TextAlign.left,
          TableAlignment.center => TextAlign.center,
          TableAlignment.right => TextAlign.right,
        },
        style: isHeader
            ? Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
            : Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _CodeBlockCard extends StatelessWidget {
  const _CodeBlockCard({
    required this.code,
    required this.language,
    required this.showLineNumbers,
  });

  final String code;
  final String? language;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = code.split('\n');
    final display = showLineNumbers
        ? [
            for (var i = 0; i < lines.length; i++)
              '${(i + 1).toString().padLeft(2, '0')}  ${lines[i]}',
          ].join('\n')
        : code;

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  language?.isNotEmpty == true ? language! : 'code',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.content_copy_rounded),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                display,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
