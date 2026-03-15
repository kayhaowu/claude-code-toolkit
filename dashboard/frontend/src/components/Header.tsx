export function Header() {
  return (
    <header className="flex items-center justify-between border-b border-gray-800 px-6 py-3">
      <h1 className="text-lg font-bold text-blue-400">Dashboard</h1>
      <nav className="flex gap-1">
        <span className="px-3 py-1.5 rounded text-sm bg-blue-600 text-white">
          Session Monitor
        </span>
      </nav>
    </header>
  );
}
