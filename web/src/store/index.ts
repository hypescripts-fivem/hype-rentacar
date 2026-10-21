import { defineStore } from 'pinia';
import { FetchNUI, isNative } from '../utils';

export interface PlayerInfo {
    id: number;
    firstname: string;
    lastname: string;
    cash: number;
    bank: number;
}

export interface UIConfig {
    accent: string;
    numberLocale: string;
    currency: string;
}

export interface Vehicle {
    model: string;
    label: string;
    category: string;
    price: number;
    deposit: number;
    image: string;
}

export type SortMode = 'default' | 'price_asc' | 'price_desc' | 'name';

export const sortModes: SortMode[] = ['default', 'price_asc', 'price_desc', 'name'];

export interface Duration {
    hours: number;
    discount: number;
}

export interface Rental {
    id: number;
    location?: string;
    locationLabel?: string;
    model: string;
    label: string;
    plate: string;
    hours: number;
    deposit: number;
    payment: string;
    remaining: number;
    pickedUp?: boolean;
    vehicleExists: boolean;
    vehicleNear: boolean;
    endsAt: number;
}

export interface PendingPickup {
    id: number;
    model: string;
    label: string;
    plate: string;
    hours: number;
    image: string;
    remaining: number;
    available: boolean;
}

export interface PickupPayload {
    locales?: Record<string, string>;
    ui?: UIConfig;
    company?: { name: string; location: string };
    rentals: PendingPickup[];
}

type RawRental = Omit<Rental, 'endsAt'>;

interface PlayerData {
    player: PlayerInfo;
    license: boolean;
    rentals: RawRental[];
}

interface ReturnResult extends PlayerData {
    returned: { label: string; plate: string; deposit: number; refund: number; missing: boolean };
}

export interface OpenPayload {
    locales?: Record<string, string>;
    ui?: UIConfig;
    company?: { name: string; location: string };
    player?: PlayerInfo;
    license?: boolean;
    requireLicense?: boolean;
    maxRentals?: number;
    rentals?: RawRental[];
    vehicles?: Vehicle[];
    durations?: Duration[];
    accounts?: string[];
}

const image = (model: string) => `https://docs.fivem.net/vehicles/${model}.webp`;

const mock = {
    ui: { accent: '#fafafa', numberLocale: 'en-US', currency: '$' } as UIConfig,
    company: { name: 'Los Santos Rent a Car', location: 'Legion Square' },
    player: { id: 12, firstname: 'John', lastname: 'Doe', cash: 15420, bank: 1250300 } as PlayerInfo,
    vehicles: [
        { model: 'panto', label: 'Benefactor Panto', category: 'compact', price: 40, deposit: 300, image: image('panto') },
        { model: 'asbo', label: 'Maxwell Asbo', category: 'compact', price: 50, deposit: 400, image: image('asbo') },
        { model: 'blista', label: 'Dinka Blista', category: 'compact', price: 60, deposit: 400, image: image('blista') },
        { model: 'asea', label: 'Declasse Asea', category: 'sedan', price: 70, deposit: 500, image: image('asea') },
        { model: 'primo', label: 'Albany Primo', category: 'sedan', price: 80, deposit: 500, image: image('primo') },
        { model: 'tailgater', label: 'Obey Tailgater', category: 'sedan', price: 120, deposit: 800, image: image('tailgater') },
        { model: 'baller', label: 'Gallivanter Baller', category: 'suv', price: 150, deposit: 1000, image: image('baller') },
        { model: 'granger', label: 'Declasse Granger', category: 'suv', price: 140, deposit: 1000, image: image('granger') },
        { model: 'sultan', label: 'Karin Sultan', category: 'sport', price: 220, deposit: 2000, image: image('sultan') },
        { model: 'faggio', label: 'Pegassi Faggio', category: 'motorcycle', price: 25, deposit: 200, image: image('faggio') },
        { model: 'bati', label: 'Pegassi Bati 801', category: 'motorcycle', price: 160, deposit: 1500, image: image('bati') },
        { model: 'speedo', label: 'Vapid Speedo', category: 'van', price: 110, deposit: 800, image: image('speedo') },
    ] as Vehicle[],
    durations: [
        { hours: 1, discount: 0 },
        { hours: 2, discount: 0 },
        { hours: 4, discount: 5 },
        { hours: 8, discount: 10 },
        { hours: 24, discount: 20 },
    ] as Duration[],
};

const withEndsAt = (rentals: RawRental[] = []): Rental[] =>
    rentals.map((rental) => ({ ...rental, endsAt: Date.now() + rental.remaining * 1000 }));

let noticeTimer: ReturnType<typeof setTimeout> | undefined;

export const useDefaultData = defineStore('DefaultData', {
    state: () => ({
        visible: !isNative,
        locales: {} as Record<string, string>,
        ui: mock.ui,
        company: mock.company,
        player: mock.player,
        license: true,
        requireLicense: true,
        maxRentals: 1,
        rentals: [] as Rental[],
        vehicles: mock.vehicles,
        durations: mock.durations,
        accounts: ['cash', 'bank'],
        category: 'all',
        search: '',
        sort: 'default' as SortMode,
        selected: null as string | null,
        hours: 1,
        payment: 'cash',
        busy: false,
        error: null as string | null,
        notice: null as string | null,
        pickup: null as { rentals: PendingPickup[]; endsAt: Record<number, number> } | null,
    }),
    getters: {
        locale: (state) => (key: string, ...args: (string | number)[]): string => {
            const text = state.locales[key] ?? key;
            if (!args.length) return text;

            let index = 0;
            return text.replace(/%[sd]/g, () => String(args[index++] ?? ''));
        },
        money: (state) => (value: number): string =>
            state.ui.currency + new Intl.NumberFormat(state.ui.numberLocale).format(value ?? 0),
        categories(state): string[] {
            const list = ['all'];
            for (const vehicle of state.vehicles) {
                if (!list.includes(vehicle.category)) list.push(vehicle.category);
            }
            return list;
        },
        filtered(state): Vehicle[] {
            const query = state.search.trim().toLocaleLowerCase(state.ui.numberLocale);
            const list = state.vehicles.filter((vehicle) => {
                if (state.category !== 'all' && vehicle.category !== state.category) return false;
                if (!query) return true;
                return `${vehicle.label} ${vehicle.model}`.toLocaleLowerCase(state.ui.numberLocale).includes(query);
            });

            if (state.sort === 'price_asc') list.sort((a, b) => a.price - b.price);
            else if (state.sort === 'price_desc') list.sort((a, b) => b.price - a.price);
            else if (state.sort === 'name') list.sort((a, b) => a.label.localeCompare(b.label, state.ui.numberLocale));
            return list;
        },
        vehicle(state): Vehicle | null {
            return state.vehicles.find((vehicle) => vehicle.model === state.selected) ?? null;
        },
        duration(state): Duration {
            return state.durations.find((duration) => duration.hours === state.hours) ?? state.durations[0] ?? { hours: 1, discount: 0 };
        },
        quote(): { base: number; discount: number; rent: number; deposit: number; total: number } {
            const vehicle = this.vehicle;
            if (!vehicle) return { base: 0, discount: 0, rent: 0, deposit: 0, total: 0 };

            const base = vehicle.price * this.duration.hours;
            const rent = Math.floor((base * (100 - this.duration.discount)) / 100 + 0.5);
            return { base, discount: base - rent, rent, deposit: vehicle.deposit, total: rent + vehicle.deposit };
        },
        balance(state): number {
            return state.payment === 'bank' ? state.player.bank : state.player.cash;
        },
        blockedReason(state): string | null {
            if (state.requireLicense && !state.license) return 'no_license';
            if (state.rentals.length >= state.maxRentals) return 'max_rentals';
            if (this.balance < this.quote.total) return 'no_money';
            return null;
        },
    },
    actions: {
        Open(payload: OpenPayload) {
            this.locales = payload.locales ?? {};
            if (payload.ui) this.ui = payload.ui;
            if (payload.company) this.company = payload.company;
            if (payload.player) this.player = payload.player;
            if (payload.vehicles) this.vehicles = payload.vehicles;
            if (payload.durations?.length) this.durations = payload.durations;
            if (payload.accounts?.length) this.accounts = payload.accounts;

            this.license = payload.license ?? true;
            this.requireLicense = payload.requireLicense ?? true;
            this.maxRentals = payload.maxRentals ?? 1;
            this.rentals = withEndsAt(payload.rentals);

            this.category = 'all';
            this.search = '';
            this.sort = 'default';
            this.selected = null;
            this.hours = this.durations[0]?.hours ?? 1;
            this.payment = this.accounts[0] ?? 'cash';
            this.busy = false;
            this.error = null;
            this.notice = null;
            this.visible = true;
        },
        OpenPickup(payload: PickupPayload) {
            this.locales = payload.locales ?? this.locales;
            if (payload.ui) this.ui = payload.ui;
            if (payload.company) this.company = payload.company;

            const endsAt: Record<number, number> = {};
            for (const rental of payload.rentals) endsAt[rental.id] = Date.now() + rental.remaining * 1000;

            this.pickup = { rentals: payload.rentals, endsAt };
            this.busy = false;
            this.error = null;
        },
        HidePickup() {
            this.pickup = null;
            this.error = null;
        },
        ClosePickup() {
            if (!this.pickup || this.busy) return;
            this.HidePickup();
            FetchNUI('nui/pickup:close');
        },
        async Pickup(id: number) {
            if (this.busy) return;

            this.Sound('select');
            this.busy = true;
            this.error = null;

            const response = await FetchNUI('nui/pickup', { id });
            this.busy = false;

            if (!response.success) {
                this.error = response.error ?? 'invalid';
                return;
            }

            if (!isNative) {
                this.HidePickup();
                this.Hide();
            }
        },
        Hide() {
            this.visible = false;
            this.selected = null;
            this.error = null;
        },
        CloseUI() {
            if (!this.visible) return;
            this.Hide();
            FetchNUI('nui/close');
        },
        Sound(type: 'hover' | 'select') {
            FetchNUI('nui/sound', { type });
        },
        SetCategory(category: string) {
            if (this.category === category) return;
            this.Sound('hover');
            this.category = category;
        },
        SetSort(sort: SortMode) {
            if (this.sort === sort) return;
            this.Sound('hover');
            this.sort = sort;
        },
        Select(model: string | null) {
            this.Sound('select');
            this.error = null;
            this.selected = model;
        },
        SetHours(hours: number) {
            if (this.hours === hours) return;
            this.Sound('hover');
            this.error = null;
            this.hours = hours;
        },
        SetPayment(account: string) {
            if (this.payment === account) return;
            this.Sound('hover');
            this.error = null;
            this.payment = account;
        },
        Notify(text: string) {
            this.notice = text;
            clearTimeout(noticeTimer);
            noticeTimer = setTimeout(() => (this.notice = null), 5000);
        },
        async Rent() {
            const vehicle = this.vehicle;
            if (!vehicle || this.busy || this.blockedReason) return;

            this.Sound('select');
            this.busy = true;
            this.error = null;

            const response = await FetchNUI('nui/rent', { model: vehicle.model, hours: this.hours, payment: this.payment });
            this.busy = false;

            if (!response.success) {
                this.error = response.error ?? 'invalid';
                return;
            }

            if (!isNative) this.Hide();
        },
        async Respawn(id: number) {
            if (this.busy) return;

            this.Sound('select');
            this.busy = true;
            this.error = null;

            const response = await FetchNUI<PlayerData>('nui/respawn', { id });
            this.busy = false;

            if (!response.success) {
                this.error = response.error ?? 'invalid';
                return;
            }

            if (!isNative) this.Hide();
        },
        async Return(id: number) {
            if (this.busy) return;

            this.Sound('select');
            this.busy = true;
            this.error = null;

            const rental = this.rentals.find((item) => item.id === id);
            const response = await FetchNUI<ReturnResult>('nui/return', { id }, {
                player: this.player,
                license: this.license,
                rentals: [],
                returned: { label: rental?.label ?? '', plate: rental?.plate ?? '', deposit: rental?.deposit ?? 0, refund: rental?.deposit ?? 0, missing: false },
            });
            this.busy = false;

            if (!response.success || !response.data) {
                this.error = response.error ?? 'invalid';
                return;
            }

            const { player, license, rentals, returned } = response.data;
            this.player = player;
            this.license = license;
            this.rentals = withEndsAt(rentals);
            this.Notify(returned.missing
                ? this.locale('ui.rental.returned_missing', returned.label)
                : this.locale('ui.rental.returned', returned.label, this.money(returned.refund)));
        },
    },
});
