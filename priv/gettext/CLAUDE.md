# Gettext Translation Directory

Internationalization (i18n) and localization (l10n) data persistence for VSM Phoenix.

## Directory Structure:

### en/LC_MESSAGES/
English language translations:
- `default.po` - General application strings
- `errors.po` - Error message translations

## Translation Persistence:

### File Format
PO (Portable Object) files storing:
- Message IDs (original strings)
- Translated strings
- Translator comments
- Source code references
- Plural forms

### Example Entry
```
#: lib/vsm_phoenix/system1/operations.ex:42
msgid "Operation completed successfully"
msgstr "Operation completed successfully"

#: lib/vsm_phoenix/errors.ex:15
msgid "Invalid variety ratio: %{ratio}"
msgstr "Invalid variety ratio: %{ratio}"
```

## Persistence Features:

### Compilation
- PO files compiled to MO (Machine Object) format
- Binary format for runtime efficiency
- Automatic compilation on build
- Hot-reload in development

### Versioning
- Translation changes tracked in git
- Preserves translation history
- Supports rollback
- Merge-friendly format

### Extraction
```bash
# Extract new strings from code
mix gettext.extract

# Merge with existing translations
mix gettext.merge priv/gettext
```

## Integration with VSM:

### Dynamic Messages
- System status messages
- Error descriptions
- User notifications
- Telemetry labels

### Context Support
```elixir
# Domain-specific translations
dgettext("telemetry", "Signal peak detected")
dgettext("variety", "Imbalance threshold exceeded")
```

### Pluralization
```elixir
# Handles singular/plural forms
ngettext("1 event", "%{count} events", event_count)
```

## Best Practices:

### String Management
- Use meaningful message IDs
- Include context comments
- Group related translations
- Maintain consistency

### Performance
- Translations cached at runtime
- Lazy loading of domains
- Minimal memory footprint
- Fast lookup optimization

## Adding Languages:
1. Create new language directory (e.g., `es/LC_MESSAGES/`)
2. Copy PO files from template
3. Translate strings
4. Compile with `mix compile.gettext`