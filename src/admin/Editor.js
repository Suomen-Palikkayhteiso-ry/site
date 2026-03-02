import { EditorView, keymap, lineNumbers } from '@codemirror/view';
import { EditorState } from '@codemirror/state';
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
import { markdown } from '@codemirror/lang-markdown';
import { oneDark } from '@codemirror/theme-one-dark';

let editorView = null;
let onChangeCb = null;
let suppressNext = false;

/**
 * Mount the editor into the DOM element with id="cm-editor".
 * Call this after the Admin route's view has rendered the container div.
 * @param {function(string): void} onChange - called on every content change
 */
export function mountEditor(onChange) {
  const container = document.getElementById('cm-editor');
  if (!container || editorView) return;

  onChangeCb = onChange;

  const updateListener = EditorView.updateListener.of((update) => {
    if (update.docChanged && onChangeCb && !suppressNext) {
      onChangeCb(update.state.doc.toString());
    }
  });

  editorView = new EditorView({
    state: EditorState.create({
      doc: '',
      extensions: [
        history(),
        keymap.of([...defaultKeymap, ...historyKeymap]),
        lineNumbers(),
        markdown(),
        oneDark,
        updateListener,
        EditorView.theme({ '&': { height: '60vh', fontSize: '14px' } }),
      ],
    }),
    parent: container,
  });
}

/** Replace editor content without triggering onChange. */
export function setContent(text) {
  if (!editorView) return;
  suppressNext = true;
  const transaction = editorView.state.update({
    changes: { from: 0, to: editorView.state.doc.length, insert: text },
  });
  editorView.dispatch(transaction);
  suppressNext = false;
}

/** Unmount editor (call when navigating away). */
export function destroyEditor() {
  if (editorView) {
    editorView.destroy();
    editorView = null;
    onChangeCb = null;
  }
}
