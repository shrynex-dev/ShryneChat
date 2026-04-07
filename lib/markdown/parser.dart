import 'ast.dart';

class MarkdownParser {
  MarkdownDocument parse(String input) {
    final normalized = input.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final blocks = <BlockNode>[];
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];
      if (line.trim().isEmpty) {
        index++;
        continue;
      }

      if (_isFence(line)) {
        final parsed = _parseCodeBlock(lines, index);
        blocks.add(parsed.node);
        index = parsed.nextIndex;
        continue;
      }

      if (_isHorizontalRule(line)) {
        blocks.add(const HorizontalRuleNode());
        index++;
        continue;
      }

      if (_isHeading(line)) {
        final level = line.indexOf(' ');
        blocks.add(
          HeadingNode(
            level: level.clamp(1, 6),
            inlines: _parseInlines(line.substring(level + 1).trim()),
          ),
        );
        index++;
        continue;
      }

      if (_isTableHeader(lines, index)) {
        final parsed = _parseTable(lines, index);
        blocks.add(parsed.node);
        index = parsed.nextIndex;
        continue;
      }

      if (_isBlockquote(line)) {
        final parsed = _parseBlockquote(lines, index);
        blocks.add(parsed.node);
        index = parsed.nextIndex;
        continue;
      }

      if (_isListItem(line)) {
        final parsed = _parseList(lines, index, _leadingSpaces(line));
        blocks.add(parsed.node);
        index = parsed.nextIndex;
        continue;
      }

      final parsed = _parseParagraph(lines, index);
      blocks.add(parsed.node);
      index = parsed.nextIndex;
    }

    return MarkdownDocument(blocks);
  }

  _ParsedBlock<CodeBlockNode> _parseCodeBlock(List<String> lines, int start) {
    final opening = lines[start].trim();
    final language = opening.length > 3 ? opening.substring(3).trim() : null;
    final buffer = <String>[];
    var index = start + 1;
    while (index < lines.length && !_isFence(lines[index])) {
      buffer.add(lines[index]);
      index++;
    }
    return _ParsedBlock(
      node: CodeBlockNode(
        language: language?.isEmpty == true ? null : language,
        code: buffer.join('\n'),
      ),
      nextIndex: index < lines.length ? index + 1 : index,
    );
  }

  _ParsedBlock<ParagraphNode> _parseParagraph(List<String> lines, int start) {
    final buffer = <String>[];
    var index = start;

    while (index < lines.length) {
      final line = lines[index];
      if (line.trim().isEmpty ||
          _isFence(line) ||
          _isHorizontalRule(line) ||
          _isHeading(line) ||
          _isBlockquote(line) ||
          _isListItem(line) ||
          _isTableHeader(lines, index)) {
        break;
      }
      buffer.add(line.trimRight());
      index++;
    }

    return _ParsedBlock(
      node: ParagraphNode(_parseInlines(buffer.join('\n'))),
      nextIndex: index,
    );
  }

  _ParsedBlock<BlockquoteNode> _parseBlockquote(List<String> lines, int start) {
    final content = <String>[];
    var index = start;
    while (index < lines.length && _isBlockquote(lines[index])) {
      content.add(lines[index].trimLeft().substring(1).trimLeft());
      index++;
    }
    return _ParsedBlock(
      node: BlockquoteNode(parse(content.join('\n')).blocks),
      nextIndex: index,
    );
  }

  _ParsedBlock<ListNode> _parseList(
    List<String> lines,
    int start,
    int baseIndent,
  ) {
    final items = <ListItemNode>[];
    MarkdownListKind? kind;
    var index = start;

    while (index < lines.length) {
      final line = lines[index];
      if (!_isListItem(line) || _leadingSpaces(line) < baseIndent) {
        break;
      }
      if (_leadingSpaces(line) > baseIndent) {
        break;
      }

      final marker = _parseListMarker(line.trimLeft());
      kind ??= marker.kind;

      final inlineContent = marker.content;
      index++;

      final childLists = <ListNode>[];
      while (index < lines.length &&
          _isListItem(lines[index]) &&
          _leadingSpaces(lines[index]) > baseIndent) {
        final childParsed = _parseList(
          lines,
          index,
          _leadingSpaces(lines[index]),
        );
        childLists.add(childParsed.node);
        index = childParsed.nextIndex;
      }

      items.add(
        ListItemNode(
          inlines: _parseInlines(inlineContent),
          checked: marker.checked,
          children: childLists,
        ),
      );
    }

    return _ParsedBlock(
      node: ListNode(kind: kind ?? MarkdownListKind.unordered, items: items),
      nextIndex: index,
    );
  }

  _ParsedBlock<TableNode> _parseTable(List<String> lines, int start) {
    final headers = _splitTableRow(
      lines[start],
    ).map(_parseInlines).toList(growable: false);
    final alignments = _parseTableAlignment(lines[start + 1]);
    final rows = <List<List<InlineNode>>>[];
    var index = start + 2;
    while (index < lines.length &&
        lines[index].contains('|') &&
        lines[index].trim().isNotEmpty) {
      rows.add(
        _splitTableRow(lines[index]).map(_parseInlines).toList(growable: false),
      );
      index++;
    }

    return _ParsedBlock(
      node: TableNode(headers: headers, alignments: alignments, rows: rows),
      nextIndex: index,
    );
  }

  List<TableAlignment> _parseTableAlignment(String line) {
    return _splitTableRow(line)
        .map((cell) {
          final trimmed = cell.trim();
          final left = trimmed.startsWith(':');
          final right = trimmed.endsWith(':');
          if (left && right) {
            return TableAlignment.center;
          }
          if (right) {
            return TableAlignment.right;
          }
          return TableAlignment.left;
        })
        .toList(growable: false);
  }

  List<String> _splitTableRow(String line) {
    final trimmed = line.trim();
    final content = trimmed.startsWith('|') ? trimmed.substring(1) : trimmed;
    final withoutTail = content.endsWith('|')
        ? content.substring(0, content.length - 1)
        : content;
    return withoutTail
        .split('|')
        .map((cell) => cell.trim())
        .toList(growable: false);
  }

  List<InlineNode> _parseInlines(String source) {
    final nodes = <InlineNode>[];
    var index = 0;

    while (index < source.length) {
      if (source.startsWith('\n', index)) {
        nodes.add(const LineBreakNode());
        index++;
        continue;
      }
      if (source.startsWith('***', index)) {
        final end = source.indexOf('***', index + 3);
        if (end > index) {
          nodes.add(
            StrongEmphasisNode(_parseInlines(source.substring(index + 3, end))),
          );
          index = end + 3;
          continue;
        }
      }
      if (source.startsWith('**', index)) {
        final end = source.indexOf('**', index + 2);
        if (end > index) {
          nodes.add(
            StrongNode(_parseInlines(source.substring(index + 2, end))),
          );
          index = end + 2;
          continue;
        }
      }
      if (source.startsWith('~~', index)) {
        final end = source.indexOf('~~', index + 2);
        if (end > index) {
          nodes.add(
            StrikethroughNode(_parseInlines(source.substring(index + 2, end))),
          );
          index = end + 2;
          continue;
        }
      }
      if (source.startsWith('*', index) || source.startsWith('_', index)) {
        final marker = source[index];
        final end = source.indexOf(marker, index + 1);
        if (end > index) {
          nodes.add(
            EmphasisNode(_parseInlines(source.substring(index + 1, end))),
          );
          index = end + 1;
          continue;
        }
      }
      if (source.startsWith('`', index)) {
        final end = source.indexOf('`', index + 1);
        if (end > index) {
          nodes.add(InlineCodeNode(source.substring(index + 1, end)));
          index = end + 1;
          continue;
        }
      }
      if (source.startsWith('[', index)) {
        final close = source.indexOf(']', index + 1);
        final openParen = close == -1 ? -1 : source.indexOf('(', close);
        final closeParen = openParen == -1
            ? -1
            : source.indexOf(')', openParen);
        if (close > index && openParen == close + 1 && closeParen > openParen) {
          nodes.add(
            LinkNode(
              label: _parseInlines(source.substring(index + 1, close)),
              url: source.substring(openParen + 1, closeParen),
            ),
          );
          index = closeParen + 1;
          continue;
        }
      }

      final autolink = _matchAutolink(source, index);
      if (autolink != null) {
        nodes.add(LinkNode(label: [TextNode(autolink)], url: autolink));
        index += autolink.length;
        continue;
      }

      final next = _findNextSpecial(source, index);
      nodes.add(TextNode(source.substring(index, next)));
      index = next;
    }

    return nodes;
  }

  String? _matchAutolink(String source, int index) {
    const schemes = ['https://', 'http://'];
    for (final scheme in schemes) {
      if (source.startsWith(scheme, index)) {
        final remainder = source.substring(index);
        final match = RegExp(r'^\S+').firstMatch(remainder);
        return match?.group(0);
      }
    }
    return null;
  }

  int _findNextSpecial(String source, int start) {
    final markers = [
      '***',
      '**',
      '~~',
      '*',
      '_',
      '`',
      '[',
      'http://',
      'https://',
      '\n',
    ];
    var next = source.length;
    for (final marker in markers) {
      final found = source.indexOf(marker, start);
      if (found != -1 && found < next) {
        next = found;
      }
    }
    return next;
  }

  bool _isFence(String line) => line.trimLeft().startsWith('```');

  bool _isHorizontalRule(String line) {
    final trimmed = line.trim();
    return trimmed == '---' || trimmed == '***';
  }

  bool _isHeading(String line) {
    return RegExp(r'^#{1,6}\s').hasMatch(line.trimLeft());
  }

  bool _isBlockquote(String line) => line.trimLeft().startsWith('>');

  bool _isListItem(String line) {
    return RegExp(r'^\s*(?:[-*+]\s|\d+\.\s|-\s\[[ xX]\]\s)').hasMatch(line);
  }

  bool _isTableHeader(List<String> lines, int index) {
    if (index + 1 >= lines.length) {
      return false;
    }
    return lines[index].contains('|') &&
        RegExp(r'^\s*\|?[:\- ]+\|[:\-| ]+\|?\s*$').hasMatch(lines[index + 1]);
  }

  int _leadingSpaces(String line) {
    return line.length - line.trimLeft().length;
  }

  _ListMarker _parseListMarker(String line) {
    final task = RegExp(
      r'^-\s\[(?<checked>[ xX])\]\s(?<content>.*)$',
    ).firstMatch(line);
    if (task != null) {
      return _ListMarker(
        kind: MarkdownListKind.task,
        content: task.namedGroup('content') ?? '',
        checked: (task.namedGroup('checked') ?? '').toLowerCase() == 'x',
      );
    }
    final ordered = RegExp(r'^\d+\.\s(?<content>.*)$').firstMatch(line);
    if (ordered != null) {
      return _ListMarker(
        kind: MarkdownListKind.ordered,
        content: ordered.namedGroup('content') ?? '',
      );
    }
    final unordered = RegExp(r'^[-*+]\s(?<content>.*)$').firstMatch(line);
    return _ListMarker(
      kind: MarkdownListKind.unordered,
      content: unordered?.namedGroup('content') ?? line,
    );
  }
}

class _ParsedBlock<T extends BlockNode> {
  const _ParsedBlock({required this.node, required this.nextIndex});

  final T node;
  final int nextIndex;
}

class _ListMarker {
  const _ListMarker({required this.kind, required this.content, this.checked});

  final MarkdownListKind kind;
  final String content;
  final bool? checked;
}
