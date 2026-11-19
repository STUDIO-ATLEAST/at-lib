<script lang="ts" module>
  type Token =
    | { kind: "text"; value: string }
    | { kind: "code"; value: string }
    | { kind: "bold"; value: string }
    | { kind: "italic"; value: string }
    | { kind: "strike"; value: string }
    | { kind: "link"; value: string; href: string };

  const PATTERN =
    /`([^`]+)`|\*\*([^*]+)\*\*|__([^_]+)__|\*([^*]+)\*|_([^_]+)_|~~([^~]+)~~|\[([^\]]+)\]\(([^)\s]+)\)/g;

  export function tokenize(source: string): Token[] {
    const tokens: Token[] = [];
    let last = 0;

    for (const match of source.matchAll(PATTERN)) {
      const index = match.index ?? 0;
      if (index > last) tokens.push({ kind: "text", value: source.slice(last, index) });

      if (match[1] !== undefined) tokens.push({ kind: "code", value: match[1] });
      else if (match[2] !== undefined) tokens.push({ kind: "bold", value: match[2] });
      else if (match[3] !== undefined) tokens.push({ kind: "bold", value: match[3] });
      else if (match[4] !== undefined) tokens.push({ kind: "italic", value: match[4] });
      else if (match[5] !== undefined) tokens.push({ kind: "italic", value: match[5] });
      else if (match[6] !== undefined) tokens.push({ kind: "strike", value: match[6] });
      else tokens.push({ kind: "link", value: match[7], href: match[8] });

      last = index + match[0].length;
    }

    if (last < source.length) tokens.push({ kind: "text", value: source.slice(last) });
    return tokens;
  }
</script>

<script lang="ts">
  let { text }: { text: string } = $props();

  const tokens = $derived(tokenize(text));
</script>

{#each tokens as token, index (index)}
  {#if token.kind === "text"}{token.value}
  {:else if token.kind === "code"}<code>{token.value}</code>
  {:else if token.kind === "bold"}<strong>{token.value}</strong>
  {:else if token.kind === "italic"}<em>{token.value}</em>
  {:else if token.kind === "strike"}<s>{token.value}</s>
  {:else}<a href={token.href} target="_blank" rel="noreferrer">{token.value}</a>
  {/if}
{/each}
