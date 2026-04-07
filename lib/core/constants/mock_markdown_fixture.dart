const mockAssistantMarkdown = '''
# Shryne Response Demo

This mock reply demonstrates the **custom markdown renderer** with _full-width assistant content_, readable spacing, and `inline code`.

## Why this layout feels calm

> User prompts stay compact and personal.
> Assistant answers expand into a readable canvas instead of cramped bubbles.

### Quick checklist

- Reading-focused width
- Soft hierarchy for headings
- Stable code presentation
  - Nested bullet support
  - Smooth scrolling for long blocks
- Link support with clear affordances

### Task list

- [x] Persist the conversation locally
- [x] Render markdown from a custom parser
- [ ] Replace this mock transport with a live model API

---

## Ordered steps

1. Create a conversation.
2. Store the user message.
3. Store the assistant markdown.
4. Rehydrate the full thread from SQLite.

## Table rendering

| Area | Priority | Notes |
|:-----|:-------:|------:|
| Thread list | High | Fast scan |
| Markdown parser | High | Custom AST |
| Settings | Medium | Local only |
| Search | Future | Add indexing later |

## Code blocks

```dart
sealed class ReplyState {
  const ReplyState();
}

final class ReplyReady extends ReplyState {
  const ReplyReady(this.markdown);

  final String markdown;
}
```

```sql
select conversation_id, count(*) as message_count
from messages
group by conversation_id
order by max(created_at) desc;
```

## Links

Visit [Android Developers](https://developer.android.com/) or https://flutter.dev for platform guidance.

#### Smaller heading

This paragraph verifies multiple heading levels, soft rhythm, and consistent body spacing.

##### Micro heading

The renderer also handles ~~deprecated text~~ and ***combined emphasis***.

###### Tiny heading

End of demo.
''';
