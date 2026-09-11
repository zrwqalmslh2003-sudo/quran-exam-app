export type Route =
  | { kind: 'home' }
  | { kind: 'categories' }
  | { kind: 'category'; ref: string }
  | { kind: 'exam'; examId: string; version: number }
  | { kind: 'result' };

export function parseHash(hash: string): Route {
  const raw = hash.startsWith('#') ? hash.slice(1) : hash;
  const parts = raw.split('/').filter(Boolean);
  if (parts.length === 0) return { kind: 'home' };
  const [kind, ...rest] = parts;
  if (kind === 'home') return { kind: 'home' };
  if (kind === 'categories') return { kind: 'categories' };
  if (kind === 'result') return { kind: 'result' };
  if (kind === 'category' && rest.length === 1) return { kind: 'category', ref: decodeURIComponent(rest[0]) };
  if (kind === 'exam' && rest.length === 2) {
    const version = Number(rest[1]);
    if (Number.isInteger(version) && version > 0) return { kind: 'exam', examId: decodeURIComponent(rest[0]), version };
  }
  return { kind: 'home' };
}

export function toHash(route: Route): string {
  switch (route.kind) {
    case 'home': return '#/';
    case 'categories': return '#/categories';
    case 'category': return `#/category/${encodeURIComponent(route.ref)}`;
    case 'exam': return `#/exam/${encodeURIComponent(route.examId)}/${route.version}`;
    case 'result': return '#/result';
  }
}