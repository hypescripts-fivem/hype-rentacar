import { useDefaultData, type OpenPayload, type PickupPayload } from "../store/index";

export function keydownEvent() {
    window.addEventListener("keydown", ({ code }) => {
        if (code !== "Escape") return;

        const defaultData = useDefaultData();
        if (defaultData.pickup) return defaultData.ClosePickup();
        if (!defaultData.visible || defaultData.busy) return;

        if (defaultData.selected) {
            defaultData.Select(null);
        } else if (defaultData.search) {
            defaultData.search = '';
        } else {
            defaultData.CloseUI();
        }
    });
};

interface NuiMessage {
    action: string;
    payload: any;
}

export function messageEvent() {
    const handlers: Record<string, (payload: any) => void> = {
        'nui/open': (payload: OpenPayload) => {
            useDefaultData().Open(payload ?? {});
        },
        'nui/hide': () => {
            useDefaultData().Hide();
        },
        'nui/pickup': (payload: PickupPayload) => {
            useDefaultData().OpenPickup(payload ?? { rentals: [] });
        },
        'nui/pickup:hide': () => {
            useDefaultData().HidePickup();
        },
    };

    window.addEventListener('message', ({ data }: MessageEvent<NuiMessage>) => {
        const handler = handlers[data?.action];

        if (handler) {
            handler(data.payload);
        } else {
            console.warn(`Unknown action received: ${data?.action}`);
        }
    });
};
