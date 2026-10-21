<script setup lang="ts">
import { onMounted } from 'vue';
import { keydownEvent, messageEvent } from './utils/events';
import { useDefaultData } from './store/index';
import { contrastColor } from './utils';
import AppIcon from './components/AppIcon.vue';
import ActiveRental from './components/ActiveRental.vue';
import VehicleList from './components/VehicleList.vue';
import RentalDetails from './components/RentalDetails.vue';
import PickupModal from './components/PickupModal.vue';

const defaultData = useDefaultData();

onMounted(() => {
    keydownEvent();
    messageEvent();
});
</script>

<template>
    <Transition name="panel">
        <div
            v-if="defaultData.visible"
            class="fixed inset-0 overflow-hidden font-sans text-white"
            :style="{ '--accent': defaultData.ui.accent, '--on-accent': contrastColor(defaultData.ui.accent) }"
        >
            <div class="pointer-events-none absolute inset-y-0 right-0 w-[45%] bg-linear-to-l from-black/80 via-black/40 to-transparent anim-fade" />

            <aside class="sheet anim-right absolute top-[3vh] right-[1.8vw] bottom-[3vh] flex w-[32rem] flex-col overflow-hidden">
                <header class="flex shrink-0 items-center gap-4 border-b border-line px-6 py-5">
                    <div class="grid size-10 shrink-0 place-items-center rounded-md border border-line bg-surface text-fg">
                        <AppIcon name="car" class="size-5" />
                    </div>
                    <div class="min-w-0 flex-1">
                        <div class="truncate text-xs font-medium text-dim">
                            {{ defaultData.company.name }} · {{ defaultData.company.location }}
                        </div>
                        <h2 class="text-[1.45rem] leading-tight font-bold tracking-tight">{{ defaultData.locale('ui.title') }}</h2>
                    </div>
                    <button
                        class="sheet-close grid size-9 shrink-0 cursor-pointer place-items-center text-muted"
                        @mouseenter="defaultData.Sound('hover')"
                        @click="defaultData.CloseUI()"
                    >
                        <AppIcon name="close" class="size-4" />
                    </button>
                </header>

                <div class="flex shrink-0 items-center gap-5 border-b border-line px-6 py-3">
                    <div class="min-w-0 flex-1 truncate text-sm font-semibold">
                        {{ defaultData.player.firstname }}
                        <span class="font-light text-muted">{{ defaultData.player.lastname }}</span>
                    </div>
                    <div class="text-right">
                        <div class="text-[0.65rem] font-medium tracking-wider text-dim uppercase">{{ defaultData.locale('ui.cash') }}</div>
                        <div class="text-sm font-semibold tabular-nums">{{ defaultData.money(defaultData.player.cash) }}</div>
                    </div>
                    <div class="h-6 w-px bg-line-strong" />
                    <div class="text-right">
                        <div class="text-[0.65rem] font-medium tracking-wider text-dim uppercase">{{ defaultData.locale('ui.bank') }}</div>
                        <div class="text-sm font-semibold tabular-nums">{{ defaultData.money(defaultData.player.bank) }}</div>
                    </div>
                </div>

                <Transition name="notice">
                    <div v-if="defaultData.notice" class="mx-6 mt-4 flex shrink-0 items-center gap-2 text-sm text-emerald-400">
                        <AppIcon name="check" class="size-4 shrink-0" />
                        {{ defaultData.notice }}
                    </div>
                </Transition>

                <div v-if="defaultData.rentals.length && !defaultData.selected" class="flex shrink-0 flex-col gap-2 px-6 pt-4">
                    <ActiveRental v-for="rental in defaultData.rentals" :key="rental.id" :rental="rental" />
                    <div v-if="!defaultData.selected && defaultData.error" class="flex items-center gap-2 text-sm text-red-400">
                        <AppIcon name="alert" class="size-4 shrink-0" />
                        {{ defaultData.locale(`ui.errors.${defaultData.error}`) }}
                    </div>
                </div>

                <div v-if="defaultData.requireLicense && !defaultData.license && !defaultData.selected" class="mx-6 mt-4 flex shrink-0 items-center gap-2 text-sm text-red-400">
                    <AppIcon name="alert" class="size-4 shrink-0" />
                    {{ defaultData.locale('ui.license_missing') }}
                </div>

                <Transition name="sheet-swap" mode="out-in">
                    <RentalDetails v-if="defaultData.vehicle" :key="defaultData.vehicle.model" />
                    <VehicleList v-else />
                </Transition>

                <div class="flex shrink-0 items-center justify-end gap-2 border-t border-line px-6 py-2.5 text-xs text-muted">
                    <kbd class="rounded-md border border-line-strong bg-surface px-1.5 py-px text-[0.65rem] font-medium text-muted">ESC</kbd>
                    {{ defaultData.locale(defaultData.selected ? 'ui.back' : 'ui.close') }}
                </div>
            </aside>
        </div>
    </Transition>

    <Transition name="panel">
        <PickupModal v-if="defaultData.pickup && !defaultData.visible" />
    </Transition>
</template>
