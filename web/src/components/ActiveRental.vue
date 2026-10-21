<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useDefaultData, type Rental } from '../store/index';
import { formatDuration } from '../utils';
import AppIcon from './AppIcon.vue';

const props = defineProps<{ rental: Rental }>();

const defaultData = useDefaultData();

const now = ref(Date.now());
let timer: ReturnType<typeof setInterval> | undefined;

onMounted(() => (timer = setInterval(() => (now.value = Date.now()), 1000)));
onBeforeUnmount(() => clearInterval(timer));

const remaining = computed(() => Math.max(0, (props.rental.endsAt - now.value) / 1000));
const progress = computed(() => Math.min(100, (remaining.value / (props.rental.hours * 3600)) * 100));

const pending = computed(() => props.rental.pickedUp === false);

const hint = computed(() => {
    if (pending.value) return 'pending';
    if (!props.rental.vehicleExists) return 'vehicle_missing';
    if (!props.rental.vehicleNear) return 'vehicle_far';
    return null;
});
</script>

<template>
    <div class="rental-card px-4 py-3.5">
        <div class="flex items-center gap-3">
            <span class="pulse-dot size-1.5 shrink-0 rounded-full bg-(--accent)" />
            <span class="sheet-label text-muted!">{{ defaultData.locale('ui.rental.title') }}</span>
            <span class="ml-auto rounded-md border border-line-strong bg-surface px-1.5 py-px font-mono text-[0.7rem] font-semibold tracking-wider text-fg">
                {{ rental.plate }}
            </span>
        </div>

        <div class="mt-2.5 flex items-end gap-3">
            <div class="min-w-0 flex-1">
                <div class="truncate text-[1.05rem] font-semibold">{{ rental.label }}</div>
                <div class="mt-0.5 flex items-center gap-1.5 text-xs text-muted">
                    <AppIcon name="clock" class="size-3.5" />
                    {{ defaultData.locale('ui.rental.remaining') }}
                    <span class="font-semibold text-white tabular-nums">{{ formatDuration(remaining) }}</span>
                </div>
            </div>
            <button
                v-if="pending"
                class="sheet-primary flex shrink-0 cursor-pointer items-center gap-2 px-3 py-1.5 text-xs font-medium"
                :disabled="defaultData.busy"
                @mouseenter="defaultData.Sound('hover')"
                @click="defaultData.Pickup(rental.id)"
            >
                <AppIcon name="key" class="size-3.5" />
                {{ defaultData.locale('ui.rental.pickup') }}
            </button>
            <button
                v-else-if="!rental.vehicleExists"
                class="sheet-primary flex shrink-0 cursor-pointer items-center gap-2 px-3 py-1.5 text-xs font-medium"
                :disabled="defaultData.busy"
                @mouseenter="defaultData.Sound('hover')"
                @click="defaultData.Respawn(rental.id)"
            >
                <AppIcon name="key" class="size-3.5" />
                {{ defaultData.locale('ui.rental.respawn') }}
            </button>
            <button
                class="sheet-nav flex shrink-0 cursor-pointer items-center gap-2 px-3 py-1.5 text-xs font-medium"
                :disabled="defaultData.busy || hint === 'vehicle_far'"
                @mouseenter="defaultData.Sound('hover')"
                @click="defaultData.Return(rental.id)"
            >
                <AppIcon name="return" class="size-3.5" />
                {{ defaultData.locale('ui.rental.return') }}
            </button>
        </div>

        <div class="mt-3 h-0.5 overflow-hidden rounded-full bg-line">
            <div class="h-full bg-(--accent) transition-[width] duration-1000 ease-linear" :style="{ width: `${progress}%` }" />
        </div>

        <div v-if="hint" class="mt-2 flex items-center gap-1.5 text-[0.7rem] text-muted">
            <AppIcon name="alert" class="size-3 shrink-0" />
            {{ defaultData.locale(`ui.rental.${hint}`) }}
        </div>
    </div>
</template>
