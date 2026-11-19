type NuiMessage<T = unknown> = {
  action: string;
  data: T;
};

export function onNui<T = unknown>(action: string, handler: (data: T) => void) {
  const listener = (event: MessageEvent<NuiMessage<T>>) => {
    if (event.data?.action === action) handler(event.data.data);
  };
  window.addEventListener("message", listener);
  return () => window.removeEventListener("message", listener);
}
