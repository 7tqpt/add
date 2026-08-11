type ClassValue = string | number | false | null | undefined

/** Joins truthy class names. Small enough not to warrant a dependency. */
export function cn(...values: ClassValue[]): string {
  return values.filter(Boolean).join(' ')
}
