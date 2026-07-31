# Known issues

## Rich-text formatting continues after pasted text

**Status:** recorded for investigation before the next application update.

### Reproduction

1. Open an editor that supports rich text.
2. Copy text formatted in bold.
3. Paste it while KeySwitch is running.
4. Continue typing immediately after the pasted fragment.

### Observed result

New keyboard input can inherit the formatting of the pasted text. For example,
after pasting **Liquid Glass**, the following text also remains bold.

### Expected result

KeySwitch must not unexpectedly change the formatting of text typed after a
paste operation.

### Preliminary assessment

KeySwitch currently ignores keyboard events that use the Command modifier and
does not modify the pasteboard. Rich-text editors commonly inherit the typing
attributes of the text immediately before the caret, so the behavior may belong
to the host editor rather than KeySwitch.

Before implementing a fix, reproduce the issue with KeySwitch enabled and
disabled in:

- TextEdit in rich-text mode;
- Notes;
- a browser `contenteditable` field;
- a plain-text editor.

If it happens only while KeySwitch is enabled, inspect the keyboard monitor's
state reset around Command+V and any synthetic replacement events. Do not strip
pasteboard formatting globally because that would change the user's pasted
content.
