<script lang="ts" setup>
import type { CascaderOption } from 'naive-ui';
import { fetchGetDeptTagTree } from '@/service/api/dept-tag';

defineOptions({
  name: 'DeptTagCascader'
});
const props = defineProps<{
  options?: Api.DeptTag.Item[];
  excludePrivate?: boolean;
}>();

const model = defineModel<string | number | Array<number | string> | undefined | null>('value', { required: true });

const opts = ref<CascaderOption[]>([]);

async function getOptions() {
  const { error, data } = await fetchGetDeptTagTree();
  if (!error) opts.value = data as unknown as CascaderOption[];
}

onMounted(async () => {
  if (props.options) {
    opts.value = props.options as unknown as CascaderOption[];
  } else {
    await getOptions();
  }
  if (props.excludePrivate) {
    opts.value.forEach(x => {
      x.disabled = (x as unknown as Api.DeptTag.Item).tagId.startsWith('PRIVATE_');
    });
  }
});

const emit = defineEmits<{
  change: [CascaderOption | Array<CascaderOption | null> | null];
}>();

function onUpdate(
  _: string | number | Array<string | number> | null,
  option: CascaderOption | Array<CascaderOption | null> | null
) {
  emit('change', option);
}
</script>

<template>
  <NCascader
    v-model:value="model"
    placeholder="请选择院系"
    :options="opts"
    value-field="tagId"
    label-field="name"
    expand-trigger="hover"
    @update:value="onUpdate"
  />
</template>
