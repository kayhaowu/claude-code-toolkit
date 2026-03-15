import { useCallback, useRef } from 'react';

interface SplitDividerProps {
  direction: 'horizontal' | 'vertical';
  onResize: (ratio: number) => void;
}

export function SplitDivider({ direction, onResize }: SplitDividerProps) {
  const dividerRef = useRef<HTMLDivElement>(null);

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      const parent = dividerRef.current?.parentElement;
      if (!parent) return;

      const rect = parent.getBoundingClientRect();

      const onMouseMove = (ev: MouseEvent) => {
        let ratio: number;
        if (direction === 'horizontal') {
          ratio = (ev.clientX - rect.left) / rect.width;
        } else {
          ratio = (ev.clientY - rect.top) / rect.height;
        }
        ratio = Math.max(0.1, Math.min(0.9, ratio));
        onResize(ratio);
      };

      const onMouseUp = () => {
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
      };

      document.addEventListener('mousemove', onMouseMove);
      document.addEventListener('mouseup', onMouseUp);
    },
    [direction, onResize],
  );

  const isHorizontal = direction === 'horizontal';
  return (
    <div
      ref={dividerRef}
      className={`${isHorizontal ? 'w-1 cursor-col-resize' : 'h-1 cursor-row-resize'} bg-gray-700 hover:bg-blue-500 flex-shrink-0`}
      onMouseDown={handleMouseDown}
    />
  );
}
