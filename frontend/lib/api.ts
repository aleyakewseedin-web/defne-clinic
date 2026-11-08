// Shape of every error returned by the FastAPI service (see backend/app/errors.py).
export type FieldError = { field: string; message: string };

export type ApiErrorBody = {
  code: string; // stable code, used to pick a translated text (FR-9.9)
  message: string; // plain-language fallback
  fields?: FieldError[]; // set when specific inputs are wrong (FR-9.5)
};

export class ApiRequestError extends Error {
  status: number;
  body: ApiErrorBody;

  constructor(status: number, body: ApiErrorBody) {
    super(body.message);
    this.status = status;
    this.body = body;
  }
}

// Use this for every call to the API. It throws ApiRequestError on any failure.
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const base = process.env.API_URL ?? process.env.NEXT_PUBLIC_API_URL;
  const res = await fetch(`${base}${path}`, { cache: "no-store", ...init });

  if (!res.ok) {
    let body: ApiErrorBody;
    try {
      body = await res.json();
    } catch {
      body = { code: "internal_error", message: "Something went wrong. Please try again." };
    }
    throw new ApiRequestError(res.status, body);
  }
  return res.json() as Promise<T>;
}
