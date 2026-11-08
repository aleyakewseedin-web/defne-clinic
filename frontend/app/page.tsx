type Service = { id: number; name: string; duration_minutes: number };

// Server component: runs on the Next.js server and calls the FastAPI service.
export default async function HomePage() {
  const res = await fetch(`${process.env.API_URL}/services`, {
    cache: "no-store",
  });
  const services: Service[] = res.ok ? await res.json() : [];

  return (
    <>
      <h1>Services</h1>
      {services.length === 0 ? (
        <p>No services found. Is the API running?</p>
      ) : (
        <ul>
          {services.map((s) => (
            <li key={s.id}>
              {s.name} ({s.duration_minutes} min)
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
