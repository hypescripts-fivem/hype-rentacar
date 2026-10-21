<script setup lang="ts">
import { ref, watch } from 'vue';
import AppIcon from './AppIcon.vue';

const props = defineProps<{ src: string; alt: string }>();

const failed = ref(false);
watch(() => props.src, () => (failed.value = false));
</script>

<template>
    <div class="car-stage flex items-center justify-center overflow-hidden">
        <AppIcon v-if="failed" name="car" class="size-[40%] text-line-strong" />
        <img v-else :src="src" :alt="alt" class="car-img block size-full min-h-0 min-w-0 object-contain object-center" draggable="false" @error="failed = true" />
    </div>
</template>
