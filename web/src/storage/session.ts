export interface ActiveSession {
  userId: string;
  examId: string;
  version: number;
  index: number;
  answers: Record<string, number>;
  startedAt: string;
}

const KEY = 'qalon.session.active';

export function saveSession(session: ActiveSession): void {
  localStorage.setItem(KEY, JSON.stringify(session));
}

export function loadSession(): ActiveSession | null {
  const raw = localStorage.getItem(KEY);
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object') return null;
    const s = value as Partial<ActiveSession>;
    if (typeof s.userId !== 'string' || typeof s.examId !== 'string' || typeof s.version !== 'number' || typeof s.index !== 'number' || typeof s.startedAt !== 'string' || !s.answers || typeof s.answers !== 'object') return null;
    return s as ActiveSession;
  } catch {
    return null;
  }
}

export function clearSession(): void {
  localStorage.removeItem(KEY);
}
