export interface SavedError { questionId: string; prompt: string; submitted: number; }
export interface SavedResult { id: string; userId: string; examId: string; examTitle: string; version: number; startedAt: string; finishedAt: string; score: number; total: number; errors: SavedError[]; }

const KEY = 'qalon.result.last';

export function saveResult(result: SavedResult): void {
  localStorage.setItem(KEY, JSON.stringify(result));
}

export function loadLastResult(): SavedResult | null {
  const raw = localStorage.getItem(KEY);
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object') return null;
    const result = value as Partial<SavedResult>;
    if (typeof result.id !== 'string' || typeof result.userId !== 'string' || typeof result.examId !== 'string' || typeof result.examTitle !== 'string' || typeof result.version !== 'number' || typeof result.startedAt !== 'string' || typeof result.finishedAt !== 'string' || typeof result.score !== 'number' || typeof result.total !== 'number' || !Array.isArray(result.errors)) return null;
    return result as SavedResult;
  } catch {
    return null;
  }
}
