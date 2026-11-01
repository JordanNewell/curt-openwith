/*
  curt-format@1.2.0 - the .curt reference implementation, vendored for the
  viewer page from dot_curt dist/index.js (the ESM build of src/index.ts, MIT).
  A byte-for-byte copy of the try page's bundle (site/try/curt-format.js).

  dist/index.js uses ES module exports, which Chrome refuses to load over
  file:// (module requests from the null origin are blocked by CORS), and
  this page must run from file:// as much as from https. The definitions
  below are byte-for-byte the reference implementation; only the `export`
  keywords are replaced by this trailer, which attaches the same bindings
  to window.curtFormat when the file loads as a classic script:

      const { parseCurt, serializeCurt, curtFilename } = window.curtFormat;

  When the format changes in dist/index.js, vendor the change here the
  same way so the page keeps producing genuinely conforming files.
*/
// .curt reference implementation — the format contract from SPEC.md as code.
//
// Zero dependencies, no platform APIs: this file runs anywhere TypeScript
// does. curtis-ai-chat vendors it; when it changes here, port the change
// there so the spec and the app stay honest about each other.
const CURT_MAGIC = 'curtis-conversation';
const CURT_VERSION = 1;
/** Type guard for a spec-valid message ("Each message in `messages`"). */
function isCurtMessage(v) {
    if (!v || typeof v !== 'object')
        return false;
    const m = v;
    return (typeof m.id === 'string' &&
        (m.role === 'user' || m.role === 'assistant' || m.role === 'system' || m.role === 'tool') &&
        typeof m.content === 'string' &&
        typeof m.timestamp === 'number');
}
/**
 * Type guard for a spec-valid conversation ("Validation rules"). This is the
 * exact predicate `parseCurt` applies to the `conversation` field.
 */
function isCurtConversation(v) {
    if (!v || typeof v !== 'object')
        return false;
    const c = v;
    return (typeof c.id === 'string' &&
        typeof c.title === 'string' &&
        typeof c.createdAt === 'number' &&
        typeof c.updatedAt === 'number' &&
        Array.isArray(c.messages) &&
        c.messages.every(isCurtMessage));
}
/** Serialize a conversation as a .curt file body (tab-indented JSON). */
function serializeCurt(conversation, generator, extensions) {
    const file = {
        curt: CURT_MAGIC,
        version: CURT_VERSION,
        conversation,
    };
    if (generator)
        file.generator = generator;
    if (extensions?.length)
        file.extensions = [...extensions];
    return JSON.stringify(file, null, '\t');
}
/**
 * Parse a .curt body. Returns null when the magic field, version, or
 * conversation shape fails validation — a corrupted file is reported, never
 * half-parsed. Unknown fields on the conversation and its messages are
 * preserved for round-tripping. A single leading UTF-8 BOM is ignored.
 */
function parseCurt(raw) {
    // A UTF-8 BOM is not JSON, but Windows editors prepend one anyway.
    if (raw.charCodeAt(0) === 0xfeff)
        raw = raw.slice(1);
    let data;
    try {
        data = JSON.parse(raw);
    }
    catch {
        return null;
    }
    const f = data;
    if (f?.curt !== CURT_MAGIC || f?.version !== CURT_VERSION)
        return null;
    return isCurtConversation(f.conversation) ? f.conversation : null;
}
/**
 * The recommended file name for a conversation, following the Curtis
 * convention `"<YYYY-MM-DD> <slug> <suffix>.curt"` (see SPEC.md, "Bulk
 * convention"). It derives only from the immutable fields `createdAt` and
 * `id`, so the name stays stable across title edits and later updates.
 *
 * - `<date>`: `createdAt` as a UTC `YYYY-MM-DD` (`1970-01-01` if not a
 *   finite timestamp).
 * - `<slug>`: `title` lowercased, each run of letters/digits joined with `-`,
 *   capped at 50 characters, `untitled` when nothing remains.
 * - `<suffix>`: the part of `id` after the last `_`; if there is no `_` or
 *   nothing follows it, the last 8 characters of `id`.
 */
function curtFilename(conversation) {
    let date;
    try {
        date = new Date(conversation.createdAt).toISOString().slice(0, 10);
    }
    catch {
        date = '1970-01-01';
    }
    const words = conversation.title.toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
    const slug = Array.from(words.join('-'))
        .slice(0, 50)
        .join('')
        .replace(/-+$/, '') || 'untitled';
    const id = conversation.id;
    const suffix = (id.includes('_') ? id.slice(id.lastIndexOf('_') + 1) : '') || id.slice(-8);
    return `${date} ${slug} ${suffix}.curt`;
}

// Classic-script trailer (see header). No behavior is added or changed.
if (typeof window !== "undefined") {
	window.curtFormat = {
		CURT_MAGIC, CURT_VERSION,
		isCurtMessage, isCurtConversation,
		serializeCurt, parseCurt, curtFilename,
	};
}
