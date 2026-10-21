<script setup lang="ts">
import { computed } from 'vue';
import { useDefaultData } from '../store/index';
import AppIcon from './AppIcon.vue';
import CarImage from './CarImage.vue';

const defaultData = useDefaultData();

const vehicle = computed(() => defaultData.vehicle!);
const quote = computed(() => defaultData.quote);

const accountBalance = (account: string) =>
    account === 'bank' ? defaultData.player.bank : account === 'cash' ? defaultData.player.cash : 0;
</script>

<template>
    <div class="flex min-h-0 flex-1 flex-col">
        <div class="scrollbar-hide min-h-0 flex-1 overflow-y-auto px-6 pt-4 pb-5">
            <button
                class="group flex cursor-pointer items-center gap-1.5 text-xs font-medium text-muted transition-colors hover:text-white"
                @mouseenter="defaultData.Sound('hover')"
                @click="defaultData.Select(null)"
            >
                <AppIcon name="back" class="size-3.5 transition-colors group-hover:text-white" />
                {{ defaultData.locale('ui.back') }}
            </button>

            <CarImage :src="vehicle.image" :alt="vehicle.label" class="mt-3 h-[11rem] w-full rounded-lg border border-line p-4" />

            <div class="mt-4 flex items-end justify-between gap-4">
                <div class="min-w-0">
                    <div class="text-[0.65rem] font-medium tracking-wider text-muted uppercase">
                        {{ defaultData.locale(`ui.categories.${vehicle.category}`) }}
                    </div>
                    <h3 class="mt-0.5 truncate text-[1.6rem] leading-tight font-bold tracking-tight">{{ vehicle.label }}</h3>
                </div>
                <div class="shrink-0 text-right">
                    <span class="text-xl font-bold tabular-nums">{{ defaultData.money(vehicle.price) }}</span>
                    <span class="ml-1 text-xs text-muted">{{ defaultData.locale('ui.per_hour') }}</span>
                </div>
            </div>

            <div class="mt-6 sheet-label">{{ defaultData.locale('ui.details.duration') }}</div>
            <div class="mt-2 grid gap-2" :style="{ gridTemplateColumns: `repeat(${Math.min(defaultData.durations.length, 5)}, minmax(0, 1fr))` }">
                <button
                    v-for="duration in defaultData.durations"
                    :key="duration.hours"
                    class="choice flex cursor-pointer flex-col items-center px-2 pt-2.5 pb-2"
                    :class="{ 'is-active': defaultData.hours === duration.hours }"
                    @click="defaultData.SetHours(duration.hours)"
                >
                    <span v-if="duration.discount" class="choice-badge absolute -top-2 right-1 px-1.5 text-[0.6rem] font-semibold tabular-nums">
                        -{{ duration.discount }}%
                    </span>
                    <span class="text-lg leading-none font-bold tabular-nums">{{ duration.hours }}</span>
                    <span class="mt-1 text-[0.65rem] tracking-wider uppercase opacity-60">{{ defaultData.locale('ui.hour_short') }}</span>
                </button>
            </div>

            <div class="mt-5 sheet-label">{{ defaultData.locale('ui.details.payment') }}</div>
            <div class="mt-2 grid grid-cols-2 gap-2">
                <button
                    v-for="account in defaultData.accounts"
                    :key="account"
                    class="choice flex cursor-pointer items-center gap-3 px-3.5 py-2.5 text-left"
                    :class="{ 'is-active': defaultData.payment === account }"
                    @click="defaultData.SetPayment(account)"
                >
                    <span class="choice-radio size-3.5 shrink-0" />
                    <span class="min-w-0 flex-1">
                        <span class="block text-sm font-semibold">{{ defaultData.locale(`ui.${account}`) }}</span>
                        <span class="block truncate text-[0.7rem] tabular-nums opacity-60">{{ defaultData.money(accountBalance(account)) }}</span>
                    </span>
                    <AppIcon :name="account === 'bank' ? 'bank' : 'cash'" class="size-4 shrink-0 opacity-50" />
                </button>
            </div>

            <div class="mt-5 sheet-label">{{ defaultData.locale('ui.details.summary') }}</div>
            <div class="stat-tile mt-2 flex flex-col gap-2 px-4 py-3.5 text-sm">
                <div class="flex justify-between text-muted">
                    <span>{{ defaultData.locale('ui.details.base') }} <span class="text-dim">({{ defaultData.money(vehicle.price) }} × {{ defaultData.locale('ui.hours', defaultData.hours) }})</span></span>
                    <span class="tabular-nums">{{ defaultData.money(quote.base) }}</span>
                </div>
                <div v-if="quote.discount" class="flex justify-between text-emerald-400">
                    <span>{{ defaultData.locale('ui.details.discount') }} ({{ defaultData.duration.discount }}%)</span>
                    <span class="tabular-nums">-{{ defaultData.money(quote.discount) }}</span>
                </div>
                <div class="flex justify-between text-fg">
                    <span>{{ defaultData.locale('ui.details.rent_total') }}</span>
                    <span class="font-semibold tabular-nums">{{ defaultData.money(quote.rent) }}</span>
                </div>
                <div class="flex justify-between text-muted">
                    <span class="flex items-center gap-1.5"><AppIcon name="shield" class="size-3.5" />{{ defaultData.locale('ui.deposit') }}</span>
                    <span class="tabular-nums">{{ defaultData.money(quote.deposit) }}</span>
                </div>
                <p class="text-[0.7rem] leading-snug text-dim">{{ defaultData.locale('ui.details.deposit_note') }}</p>
            </div>
        </div>

        <footer class="shrink-0 border-t border-line px-6 py-4">
            <div v-if="defaultData.error || defaultData.blockedReason" class="mb-3 flex items-center gap-2 text-sm text-red-400">
                <AppIcon name="alert" class="size-4 shrink-0" />
                {{ defaultData.locale(`ui.errors.${defaultData.error ?? defaultData.blockedReason}`) }}
            </div>
            <div class="flex items-center gap-4">
                <div>
                    <div class="sheet-label">{{ defaultData.locale('ui.details.total') }}</div>
                    <div class="text-[1.6rem] leading-tight font-bold tabular-nums">{{ defaultData.money(quote.total) }}</div>
                </div>
                <button
                    class="sheet-primary ml-auto flex cursor-pointer items-center gap-2.5 px-6 py-3 text-sm font-medium"
                    :disabled="!!defaultData.blockedReason || defaultData.busy"
                    @mouseenter="defaultData.Sound('hover')"
                    @click="defaultData.Rent()"
                >
                    <AppIcon name="key" class="size-4" />
                    {{ defaultData.locale('ui.details.rent') }}
                </button>
            </div>
        </footer>
    </div>
</template>
