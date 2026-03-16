export function Header() {
  return (
    <header className="flex items-center justify-between border-b border-gray-800 px-6 py-3">
      <div className="flex items-center gap-2">
        <img src="/favicon.svg" alt="logo" width="24" height="24" style={{ imageRendering: 'pixelated' }} />
        <h1 className="text-lg font-bold text-blue-400">Claude Code Toolkit</h1>
      </div>
      <nav className="flex gap-1">
        <span className="px-3 py-1.5 rounded text-sm bg-blue-600 text-white">
          Session Monitor
        </span>
      </nav>
    </header>
  );
}
