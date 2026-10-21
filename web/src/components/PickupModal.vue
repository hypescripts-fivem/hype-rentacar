<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useDefaultData } from '../store/index';
import { contrastColor, formatDuration } from '../utils';
import AppIcon from './AppIcon.vue';
import CarImage from './CarImage.vue';

const defaultData = useDefaultData();

const now = ref(Date.now());
let timer: ReturnType<typeof setInterval> | undefined;

onMounted(() => (timer = setInterval(() => (now.value = Date.now()), 1000)));
onBeforeUnmount(() => clearInterval(timer));

const remaining = (id: number) => Math.max(0, ((defaultData.pickup?.endsAt[id] ?? 0) - now.value) / 1000);
</script>

<template>
    <div class="fixed inset-0 overflow-hidden font-sans text-white" :style="{ '--accent': defaultData.ui.accent, '--on-accent': contrastColor(defaultData.ui.accent) }">
        <div class="pointer-events-none absolute inset-y-0 right-0 w-[45%] bg-linear-to-l from-black/80 via-black/40 to-transparent anim-fade" />

        <aside class="sheet anim-right absolute top-1/2 right-[1.8vw] flex max-h-[94vh] w-[32rem] -translate-y-1/2 flex-col overflow-hidden">
            <header class="flex shrink-0 items-center gap-4 border-b border-line px-6 py-5">
                <div class="grid size-10 shrink-0 place-items-center rounded-md border border-line bg-surface text-fg">
                    <AppIcon name="key" class="size-5" />
                </div>
                <div class="min-w-0 flex-1">
                    <div class="truncate text-xs font-medium text-dim">
                        {{ defaultData.company.name }} · {{ defaultData.company.location }}
                    </div>
                    <h2 class="text-[1.45rem] leading-tight font-bold tracking-tight">{{ defaultData.locale('ui.pickup.title') }}</h2>
                </div>
                <button
                    class="sheet-close grid size-9 shrink-0 cursor-pointer place-items-center text-muted"
                    @mouseenter="defaultData.Sound('hover')"
                    @click="defaultData.ClosePickup()"
                >
                    <AppIcon name="close" class="size-4" />
                </button>
            </header>

            <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">
                <p class="text-sm leading-relaxed text-muted">{{ defaultData.locale('ui.pickup.intro') }}</p>

                <ul class="mt-5 flex flex-col gap-3">
                    <li v-for="rental in defaultData.pickup?.rentals" :key="rental.id" class="stat-tile overflow-hidden">
                        <CarImage :src="rental.image" :alt="rental.label" class="h-[9.5rem] w-full p-4" />
                        <div class="flex items-end justify-between gap-4 px-4 py-3.5">
                            <div class="min-w-0">
                                <div class="truncate text-[1.15rem] font-bold tracking-tight">{{ rental.label }}</div>
                                <div class="mt-1 flex items-center gap-3 text-xs text-muted">
                                    <span>
                                        {{ defaultData.locale('ui.pickup.plate') }}
                                        <span class="ml-1 rounded-md border border-line-strong bg-surface px-1.5 py-px font-mono font-semibold tracking-wider text-fg">{{ rental.plate }}</span>
                                    </span>
                                    <span class="flex items-center gap-1">
                                        <AppIcon name="clock" class="size-3.5" />
                                        <span class="font-semibold text-white tabular-nums">{{ formatDuration(remaining(rental.id)) }}</span>
                                    </span>
                                </div>
                            </div>
                            <button
                                class="sheet-primary flex shrink-0 cursor-pointer items-center gap-2 px-5 py-2.5 text-sm font-medium"
                                :disabled="defaultData.busy || !rental.available"
                                @mouseenter="defaultData.Sound('hover')"
                                @click="defaultData.Pickup(rental.id)"
                            >
                                <AppIcon name="key" class="size-4" />
                                {{ defaultData.locale('ui.pickup.confirm') }}
                            </button>
                        </div>
                        <div v-if="!rental.available" class="flex items-center gap-2 border-t border-line px-4 py-2.5 text-xs text-muted">
                            <AppIcon name="alert" class="size-3.5 shrink-0" />
                            {{ defaultData.locale('ui.pickup.unavailable') }}
                        </div>
                    </li>
                </ul>
            </div>

            <footer class="flex shrink-0 items-center gap-4 border-t border-line px-6 py-4">
                <div v-if="defaultData.error" class="flex min-w-0 items-center gap-2 text-sm text-red-400">
                    <AppIcon name="alert" class="size-4 shrink-0" />
                    <span class="truncate">{{ defaultData.locale(`ui.errors.${defaultData.error}`) }}</span>
                </div>
                <button
                    class="sheet-nav ml-auto flex shrink-0 cursor-pointer items-center gap-2 px-4 py-2 text-xs font-medium"
                    :disabled="defaultData.busy"
                    @mouseenter="defaultData.Sound('hover')"
                    @click="defaultData.ClosePickup()"
                >
                    <kbd class="text-[0.6rem] opacity-60">ESC</kbd>
                    {{ defaultData.locale('ui.pickup.close') }}
                </button>
            </footer>
        </aside>
    </div>
</template>
