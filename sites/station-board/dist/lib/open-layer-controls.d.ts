export type Controls<T = any> = {get(): T; subscribe(listener: () => void): () => void; remove(): void};
export function controls<T = any>(name: string, config: Record<string, unknown>): Controls<T>;
