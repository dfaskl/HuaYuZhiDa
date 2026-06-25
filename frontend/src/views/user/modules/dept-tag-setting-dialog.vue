<script setup lang="ts">
import type { FormRules } from 'naive-ui';

defineOptions({
  name: 'DeptTagSettingDialog'
});

const props = defineProps<{
  rowData: Api.User.Item;
}>();

const emit = defineEmits<{ submitted: [] }>();

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);
const { formRef, validate, restoreValidation } = useNaiveForm();
const { defaultRequiredRule } = useFormRules();

type Model = {
  deptTags: string[];
};

const model = ref<Model>(createDefaultModel());

function createDefaultModel(): Model {
  return {
    deptTags: []
  };
}

const rules = ref<FormRules>({
  deptTags: defaultRequiredRule
});

const privateDeptTag = ref<string[]>([]);
async function handleUpdateModelWhenEdit() {
  model.value = createDefaultModel();
  model.value.deptTags = props.rowData.deptTags.map(tag => tag.tagId!);
  // 备份默认的私人院系，防止被误删
  privateDeptTag.value = props.rowData.deptTags.filter(tag => tag.tagId!.startsWith('PRIVATE_')).map(tag => tag.tagId!);
}

function close() {
  visible.value = false;
}

async function handleSubmit() {
  await validate();
  loading.value = true;
  model.value.deptTags = Array.from(new Set([...model.value.deptTags, ...privateDeptTag.value]));
  const res = await request({
    method: 'PUT',
    url: `/admin/users/${props.rowData.userId}/dept-tags`,
    data: model.value
  });
  if (!res.error) {
    window.$message?.success('操作成功');
    close();
    emit('submitted');
  }
  loading.value = false;
}

watch(visible, () => {
  if (visible.value) {
    handleUpdateModelWhenEdit();
    restoreValidation();
  }
});
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="院系设置"
    :show-icon="false"
    :mask-closable="false"
    class="w-500px!"
    @positive-click="handleSubmit"
  >
    <NForm ref="formRef" :model="model" :rules="rules" label-placement="left" :label-width="100" mt-10>
      <NFormItem label="用户名" path="username">
        <NInput :value="rowData.username" readonly />
      </NFormItem>
      <NFormItem label="院系" path="deptTags">
        <DeptTagCascader v-model:value="model.deptTags" multiple exclude-private />
      </NFormItem>
    </NForm>
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" @click="handleSubmit">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<style scoped></style>
