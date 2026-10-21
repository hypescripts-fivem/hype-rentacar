<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { sortModes, useDefaultData, type SortMode } from '../store/index';
import AppIcon from './AppIcon.vue';
import CarImage from './CarImage.vue';

const defaultData = useDefaultData();

const sortOpen = ref(false);
const sortRef = ref<HTMLElement | null>(null);

const toggleSort = () => {
    defaultData.Sound('hover');
    sortOpen.value = !sortOpen.value;
};

const pickSort = (sort: SortMode) => {
    defaultData.SetSort(sort);
    sortOpen.value = false;
};

const onOutside = (event: MouseEvent) => {
    if (sortOpen.value && sortRef.value && !sortRef.value.contains(event.target as Node)) sortOpen.value = false;
};

onMounted(() => document.addEventListener('mousedown', onOutside));
onBeforeUnmount(() => document.removeEventListener('mousedown', onOutside));
</script>

<template>
    <div class="flex min-h-0 flex-1 flex-col">
        <nav class="scrollbar-hide flex shrink-0 gap-2 overflow-x-auto border-b border-line px-6 py-3">
            <button
                v-for="category in defaultData.categories"
                :key="category"
                class="sheet-tab shrink-0 cursor-pointer px-3 py-1 text-xs font-medium"
                :class="{ 'is-active': defaultData.category === category }"
                @click="defaultData.SetCategory(category)"
            >
                {{ defaultData.locale(`ui.categories.${category}`) }}
            </button>
        </nav>

        <div class="flex shrink-0 items-center gap-2 px-6 pt-4">
            <label class="sheet-search flex h-[2.4rem] min-w-0 flex-1 cursor-text items-center gap-2.5 px-3">
                <AppIcon name="search" class="size-4 shrink-0 text-dim" />
                <input
                    v-model="defaultData.search"
                    type="text"
                    maxlength="40"
                    spellcheck="false"
                    :placeholder="defaultData.locale('ui.search')"
                    class="h-full min-w-0 flex-1 bg-transparent text-sm text-white outline-none select-text placeholder:text-dim"
                />
                <button
                    v-if="defaultData.search"
                    class="grid size-5 shrink-0 cursor-pointer place-items-center rounded-sm text-muted transition-colors hover:text-white"
                    :title="defaultData.locale('ui.clear')"
                    @click.prevent="defaultData.search = ''"
                >
                    <AppIcon name="close" class="size-3.5" />
                </button>
            </label>

            <div ref="sortRef" class="relative flex shrink-0">
                <button
                    class="sheet-search flex h-[2.4rem] cursor-pointer items-center gap-2 px-3 text-xs font-semibold text-muted transition-colors hover:text-white"
                    :class="{ 'text-white!': sortOpen || defaultData.sort !== 'default' }"
                    @click="toggleSort"
                >
                    <AppIcon name="sort" class="size-3.5" :class="defaultData.sort !== 'default' ? 'text-white' : 'text-dim'" />
                    <span class="max-w-[7.5rem] truncate">{{ defaultData.locale(`ui.sort.${defaultData.sort}`) }}</span>
                    <AppIcon name="down" class="size-3.5 text-muted transition-transform" :class="{ 'rotate-180': sortOpen }" />
                </button>

                <Transition name="notice">
                    <ul v-if="sortOpen" class="sort-menu absolute top-[calc(100%+0.35rem)] right-0 z-10 w-[12rem] p-1">
                        <li class="sheet-label px-2.5 pt-1.5 pb-1">{{ defaultData.locale('ui.sort.label') }}</li>
                        <li v-for="mode in sortModes" :key="mode">
                            <button
                                class="sort-option flex w-full cursor-pointer items-center justify-between px-2.5 py-2 text-left text-sm"
                                :class="{ 'is-active': defaultData.sort === mode }"
                                @mouseenter="defaultData.Sound('hover')"
                                @click="pickSort(mode)"
                            >
                                {{ defaultData.locale(`ui.sort.${mode}`) }}
                                <AppIcon v-if="defaultData.sort === mode" name="check" class="size-3.5 text-white" />
                            </button>
                        </li>
                    </ul>
                </Transition>
            </div>
        </div>

        <div class="flex shrink-0 items-center justify-between px-6 pt-3 pb-2">
            <span class="sheet-label">{{ defaultData.locale('ui.vehicles', defaultData.filtered.length) }}</span>
            <span class="text-[0.65rem] text-dim">{{ defaultData.locale('ui.per_hour') }}</span>
        </div>

        <ul class="scrollbar-hide flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto px-6 pb-5">
            <li
                v-for="(vehicle, index) in defaultData.filtered"
                :key="`${defaultData.category}-${defaultData.sort}-${vehicle.model}`"
                class="anim-up"
                :style="{ animationDelay: `${index * 35}ms` }"
            >
                <button
                    class="car-card group flex w-full cursor-pointer items-center gap-4 p-2 pr-4 text-left"
                    @mouseenter="defaultData.Sound('hover')"
                    @click="defaultData.Select(vehicle.model)"
                >
                    <CarImage :src="vehicle.image" :alt="vehicle.label" class="h-[4.6rem] w-[8.2rem] shrink-0 rounded-md p-1.5" />

                    <span class="min-w-0 flex-1">
                        <span class="block text-[0.65rem] font-medium tracking-wider text-dim uppercase">
                            {{ defaultData.locale(`ui.categories.${vehicle.category}`) }}
                        </span>
                        <span class="mt-0.5 block truncate text-[1.02rem] font-semibold">{{ vehicle.label }}</span>
                        <span class="mt-1 flex items-center gap-1 text-[0.7rem] text-muted">
                            <AppIcon name="shield" class="size-3" />
                            {{ defaultData.locale('ui.deposit') }} {{ defaultData.money(vehicle.deposit) }}
                        </span>
                    </span>

                    <span class="shrink-0 text-right">
                        <span class="block text-lg leading-none font-bold text-fg tabular-nums">{{ defaultData.money(vehicle.price) }}</span>
                        <span class="mt-1 block text-[0.65rem] text-dim">{{ defaultData.locale('ui.per_hour') }}</span>
                    </span>

                    <AppIcon name="chevron" class="size-4 shrink-0 text-dim transition-colors group-hover:text-white" />
                </button>
            </li>

            <li v-if="!defaultData.filtered.length" class="py-10 text-center text-sm text-dim">
                {{ defaultData.locale(defaultData.search ? 'ui.no_results' : 'ui.empty') }}
            </li>
        </ul>
    </div>
</template>
