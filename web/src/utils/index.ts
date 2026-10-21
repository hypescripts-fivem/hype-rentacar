const resourceName = (): string => (window as any).GetParentResourceName?.() ?? 'hype-rentacar';

export const isNative = !!(window as any).invokeNative;

interface NuiResponse<T = unknown> {
    success: boolean;
    error?: string;
    data?: T;
};

export async function FetchNUI<T = unknown>(event: string, data?: unknown, mock?: T): Promise<NuiResponse<T>> {
    if (!isNative) {
        return { success: true, data: mock };
    }

    const response = await fetch(`https://${resourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    });

    return response.json();
};

export const formatDuration = (seconds: number): string => {
    const value = Math.max(0, Math.floor(seconds));
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${pad(Math.floor(value / 3600))}:${pad(Math.floor((value % 3600) / 60))}:${pad(value % 60)}`;
};

/** Readable text color (black/white) for a background color, based on WCAG relative luminance */
export const contrastColor = (hex: string): string => {
    let value = hex.trim().replace('#', '');
    if (value.length === 3) value = value.split('').map((c) => c + c).join('');
    if (!/^[0-9a-f]{6}$/i.test(value)) return '#111113';

    const [r, g, b] = [0, 2, 4]
        .map((i) => parseInt(value.slice(i, i + 2), 16) / 255)
        .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));

    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.179 ? '#111113' : '#ffffff';
};
