// PROMPTS
interface GenericPrompt<T extends boolean = boolean> {
  message: string;
  disableKeepCurrent?: T;
  transform?: (value: string) => string;
  defaultValue?: string;
}

interface PercentInputPrompt<T extends boolean> extends GenericPrompt<T> {
  toRay?: boolean;
}
